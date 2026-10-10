import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'totp_service.dart';
import '../models/credit_engine.dart';
import '../models/credit_account.dart';

enum UserRole { client, analyst, compliance, manager }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.client => 'Solicitante',
        UserRole.analyst => 'Analista',
        UserRole.compliance => 'Cumplimiento',
        UserRole.manager => 'Gerencia',
      };
}

class LocalUser {
  final String id;
  final String? email;
  final String name;
  final UserRole role;
  const LocalUser(
      {this.id = 'local-admin',
      this.email = 'admin@contador.local',
      this.name = 'Administrador',
      this.role = UserRole.manager});
  Map<String, dynamic>? get userMetadata => {'name': name};
}

/// Base persistente del dispositivo, independiente del espejo descartable.
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._();

  late Box _database;
  final _auth = StreamController<LocalUser?>.broadcast();
  final _changes = StreamController<void>.broadcast();
  Stream<void> get businessChanges => _changes.stream;
  LocalUser? _user;
  LocalUser? get currentUser {
    if (_user == null || !_database.isOpen) return null;
    final session = _database.get('session_v2');
    if (session is! Map ||
        !DateTime.parse(session['expires'] as String).isAfter(DateTime.now())) {
      _user = null;
      scheduleMicrotask(() => _auth.add(null));
    }
    return _user;
  }

  Stream<LocalUser?> get authStateChanges => _auth.stream;
  Map<String, dynamic> get _users =>
      Map<String, dynamic>.from(_database.get('users_v2') as Map);
  Map<String, dynamic> _credentials(String password) {
    final salt =
        base64Encode(List.generate(32, (_) => Random.secure().nextInt(256)));
    return {'salt': salt, 'hash': _passwordHash(password, salt)};
  }

  LocalUser _userFrom(Map m) => LocalUser(
      id: m['id'] as String,
      email: m['email'] as String,
      name: m['name'] as String,
      role: UserRole.values.byName(m['role'] as String));

  Future<void> init() async {
    _database = await Hive.openBox('contador_local_database_v1');
    if (!_database.containsKey('account')) {
      final salt =
          base64Encode(List.generate(32, (_) => Random.secure().nextInt(256)));
      await _database.put('account', {
        'salt': salt,
        'hash': _passwordHash('ContadorLocal2026!', salt),
      });
    }
    if (!_database.containsKey('users_v2')) {
      final users = <String, dynamic>{};
      for (final entry in {
        'admin': UserRole.manager,
        'analista': UserRole.analyst,
        'cumplimiento': UserRole.compliance,
        'cliente': UserRole.client
      }.entries) {
        final email = '${entry.key}@contador.local';
        users[email] = {
          'id': entry.key == 'admin' ? 'local-admin' : entry.key,
          'email': email,
          'name': entry.value.label,
          'role': entry.value.name,
          ...entry.key == 'admin'
              ? Map<String, dynamic>.from(_database.get('account') as Map)
              : _credentials('ContadorLocal2026!')
        };
      }
      await _database.put('users_v2', users);
      await _database.delete('session');
    }
    final session = _database.get('session_v2');
    _user = null;
    if (session is Map &&
        DateTime.parse(session['expires'] as String).isAfter(DateTime.now())) {
      final account = _users[session['email']];
      if (account is Map && account['token'] == session['token']) {
        _user = _userFrom(account);
      }
    }
  }

  String _passwordHash(String password, String salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = hmac.convert([...base64Decode(salt), 0, 0, 0, 1]).bytes;
    final result = List<int>.from(block);
    for (var i = 1; i < 100000; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return base64Encode(result);
  }

  Future<void> signIn(String email, String password, {String? otp}) async {
    final normalized = email.trim().toLowerCase();
    final users = _users;
    final raw = users[normalized];
    if (raw is! Map) throw StateError('Credenciales incorrectas.');
    final account = Map<String, dynamic>.from(raw);
    final locked = DateTime.tryParse(account['lockedUntil']?.toString() ?? '');
    if (locked != null && locked.isAfter(DateTime.now())) {
      throw StateError('Espera cinco minutos antes de reintentar.');
    }
    if (_passwordHash(password, account['salt'] as String) != account['hash'] ||
        (account['totp'] != null &&
            !TotpService.verify(account['totp'] as String, otp ?? ''))) {
      account['failures'] = (account['failures'] as int? ?? 0) + 1;
      if ((account['failures'] as int) >= 5) {
        account['lockedUntil'] =
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
      }
      users[normalized] = account;
      await _database.put('users_v2', users);
      throw StateError('Credenciales incorrectas.');
    }
    final token =
        base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)));
    account['token'] = token;
    account['failures'] = 0;
    account.remove('lockedUntil');
    users[normalized] = account;
    await _database.put('users_v2', users);
    await _database.put('session_v2', {
      'email': normalized,
      'token': token,
      'expires': DateTime.now().add(const Duration(hours: 8)).toIso8601String()
    });
    _user = _userFrom(account);
    _auth.add(_user);
  }

  Future<void> signOut() async {
    await _writes;
    await _database.delete('session_v2');
    _user = null;
    _auth.add(null);
  }

  Future<void> register(String name, String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized) ||
        password.length < 12) {
      throw ArgumentError(
          'Indica nombre, correo válido y contraseña de al menos 12 caracteres.');
    }
    final users = _users;
    if (users.containsKey(normalized)) {
      throw StateError('El correo ya está registrado.');
    }
    users[normalized] = {
      'id': 'user-${DateTime.now().microsecondsSinceEpoch}',
      'email': normalized,
      'name': name.trim(),
      'role': UserRole.client.name,
      ..._credentials(password)
    };
    await _database.put('users_v2', users);
  }

  Future<void> changePassword(String current, String next) async {
    _requireSession();
    if (next.length < 12) throw ArgumentError('Usa al menos 12 caracteres.');
    final users = _users;
    final account = Map<String, dynamic>.from(users[_user!.email] as Map);
    if (_passwordHash(current, account['salt'] as String) != account['hash']) {
      throw StateError('Contraseña actual incorrecta.');
    }
    users[_user!.email!] = {...account, ..._credentials(next)};
    await _database.put('users_v2', users);
  }

  Future<void> enableTotp(String secret, String code) async {
    _requireSession();
    if (!TotpService.verify(secret, code)) {
      throw ArgumentError('Código de autenticador incorrecto.');
    }
    final users = _users;
    final account = Map<String, dynamic>.from(users[_user!.email] as Map);
    account['totp'] = secret;
    users[_user!.email!] = account;
    await _database.put('users_v2', users);
  }

  void _requireSession() {
    if (currentUser == null) {
      throw StateError('Inicia sesión para acceder a los datos.');
    }
    final session = _database.get('session_v2');
    if (session is! Map ||
        !DateTime.parse(session['expires'] as String).isAfter(DateTime.now())) {
      throw StateError('La sesión caducó. Vuelve a iniciar sesión.');
    }
  }

  Map<String, dynamic> _snapshot() {
    final stored = _database.get('business_v2');
    if (stored != null) {
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(stored)) as Map);
    }
    return {
      for (final table in ['customers', 'loans', 'payments', 'capital_history'])
        table: jsonDecode(jsonEncode(_database.get(table, defaultValue: []))),
      'settings':
          jsonDecode(jsonEncode(_database.get('settings', defaultValue: {}))),
      'audit': <dynamic>[],
    };
  }

  Future<void> _writes = Future<void>.value();

  /// Una operación y su bitácora se guardan como una sola entrada de Hive.
  Future<T> transaction<T>(
      String action, T Function(Map<String, dynamic>) change,
      {Set<UserRole> roles = const {UserRole.manager}}) {
    final actor = _user;
    final result = _writes.then((_) async {
      _requireSession();
      if (!roles.contains(_user!.role)) {
        throw StateError('Tu rol no permite esta operación.');
      }
      if (actor == null || actor.id != _user!.id) {
        throw StateError('La sesión cambió. Reintenta.');
      }
      final state = _snapshot();
      final before = jsonEncode({...state}..remove('audit'));
      final value = change(state);
      final audit = (state['audit'] as List?) ?? [];
      final event = <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'actor': actor.id,
        'role': actor.role.name,
        'action': action,
        'date': DateTime.now().toIso8601String(),
        'before': jsonDecode(before),
        'after': {...state}..remove('audit'),
        'previous_hash': audit.isEmpty ? '' : (audit.last as Map)['hash'],
      };
      event['hash'] = sha256.convert(utf8.encode(jsonEncode(event))).toString();
      state['audit'] = [...audit, event];
      await _database.put('business_v2', state);
      _changes.add(null);
      return value;
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Map<String, dynamic> readSnapshot() {
    _requireSession();
    if (_user!.role != UserRole.manager) {
      throw StateError('Solo administración puede consultar la cartera.');
    }
    return _snapshot();
  }

  Map<String, dynamic> readWorkflow() {
    _requireSession();
    final state = _readBusinessView();
    final apps = rowsOf(state, 'applications')
        .where(
            (a) => _user!.role != UserRole.client || a['ownerId'] == _user!.id)
        .toList();
    return {
      'applications': apps,
      'credit_payments': rowsOf(state, 'credit_payments')
          .where((p) => apps.any((a) => a['id'] == p['applicationId']))
          .toList(),
      'credit_accounts': rowsOf(state, 'credit_accounts')
          .where((r) => apps.any((a) => a['id'] == r['applicationId']))
          .toList(),
      'scoring_rules': state['scoring_rules'] ?? {'version': 1, 'maxDti': 0.4}
    };
  }

  /// Screen reads do not deserialize the full historical audit on each frame.
  Map<String, dynamic> _readBusinessView() {
    final raw = _database.get('business_v2');
    if (raw is! Map) return _snapshot()..remove('audit');
    final business = Map<String, dynamic>.from(raw)..remove('audit');
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(business)) as Map);
  }

  Map<String, dynamic> readPortfolio() {
    _requireSession();
    if (_user!.role != UserRole.manager) {
      throw StateError('Solo administración puede consultar la cartera.');
    }
    return _readBusinessView();
  }

  List<Map<String, dynamic>> auditLog() =>
      rowsOf(readSnapshot(), 'audit').reversed.toList();
  static List<Map<String, dynamic>> rowsOf(
          Map<String, dynamic> state, String table) =>
      ((state[table] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  List<Map<String, dynamic>> _rows(String table) =>
      rowsOf(readSnapshot(), table);
  static void positive(dynamic value, String label, {bool allowZero = false}) {
    if (value is! num ||
        !value.isFinite ||
        (allowZero ? value < 0 : value <= 0)) {
      throw ArgumentError(
          '$label debe ser un número válido ${allowZero ? 'no negativo' : 'mayor que cero'}.');
    }
  }

  static void _validate(
      String table, Map<String, dynamic> row, Map<String, dynamic> state) {
    if (row['id'] == null || row['id'].toString().isEmpty) {
      throw ArgumentError('Falta identificador.');
    }
    if (table == 'customers' &&
        (row['name']?.toString().trim().isEmpty ?? true)) {
      throw ArgumentError('Falta nombre.');
    }
    if (table == 'loans') {
      positive(row['initial_amount'], 'Monto');
      positive(row['increment_value'] ?? 0, 'Tasa', allowZero: true);
      if (!rowsOf(state, 'customers')
          .any((c) => c['id'] == row['customer_id'])) {
        throw ArgumentError('Cliente inexistente.');
      }
      DateTime.parse(row['start_date'] as String);
    }
    if (table == 'payments') {
      positive(row['amount'], 'Pago');
      final loan = rowsOf(state, 'loans')
          .where((l) => l['id'] == row['loan_id'])
          .firstOrNull;
      if (loan == null) throw ArgumentError('Préstamo inexistente.');
      final date = DateTime.parse(row['date'] as String);
      if (date.isBefore(DateTime.parse(loan['start_date'] as String)) ||
          date.isAfter(DateTime.now())) {
        throw ArgumentError(
            'La fecha debe estar entre el inicio del préstamo y hoy.');
      }
    }
    if (table == 'capital_history' &&
        (row['amount'] is! num || !(row['amount'] as num).isFinite)) {
      throw ArgumentError('Capital inválido.');
    }
  }

  void _putRow(
      Map<String, dynamic> state, String table, Map<String, dynamic> row,
      {bool replace = false, bool validateCash = true}) {
    _validate(table, row, state);
    final rows = rowsOf(state, table);
    final index = rows.indexWhere((e) => e['id'] == row['id']);
    if (index >= 0 && !replace) throw StateError('El registro ya existe.');
    if (table == 'loans' && validateCash) {
      final increase = (row['initial_amount'] as num).toDouble() -
          (index < 0 ? 0 : (rows[index]['initial_amount'] as num).toDouble());
      if (increase > PortfolioLedger.availableCash(state) + .001) {
        throw StateError('Capital insuficiente.');
      }
    }
    final data = {
      ...row,
      'user_id': _user!.id,
      'created_at': row['created_at'] ?? DateTime.now().toIso8601String()
    };
    if (index >= 0) {
      rows[index] = data;
    } else {
      rows.add(data);
    }
    state[table] = rows;
  }

  Future<void> _insert(String table, Map<String, dynamic> data) =>
      transaction('crear:$table', (s) => _putRow(s, table, data));
  Future<void> _update(String table, String id, Map<String, dynamic> data) =>
      transaction('corregir:$table:$id', (s) {
        final old =
            rowsOf(s, table).where((e) => e['id'].toString() == id).firstOrNull;
        if (old == null) throw StateError('Registro inexistente.');
        _putRow(s, table, {...old, ...data, 'id': old['id']}, replace: true);
      });
  Future<List<Map<String, dynamic>>> getCustomers() async => _rows('customers')
    ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
  Future<List<Map<String, dynamic>>> getAllLoans() async => _rows('loans');
  Future<List<Map<String, dynamic>>> getAllPayments() async =>
      _sorted('payments', 'date');
  Future<List<Map<String, dynamic>>> getCapitalHistory() async =>
      _sorted('capital_history', 'created_at');
  List<Map<String, dynamic>> _sorted(String table, String key) => _rows(table)
    ..sort((a, b) => b[key].toString().compareTo(a[key].toString()));
  Future<List<Map<String, dynamic>>> getCustomersPaginated(
          {int limit = 5, int offset = 0, String? searchQuery}) async =>
      _sorted('customers', 'created_at')
          .where((c) =>
              searchQuery == null ||
              c['name']
                  .toString()
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
          .skip(offset)
          .take(limit)
          .toList();
  Future<List<Map<String, dynamic>>> getPaymentsPaginated(
      {String? name,
      DateTime? startDate,
      DateTime? endDate,
      int limit = 15,
      int offset = 0}) async {
    final end = endDate == null
        ? null
        : DateTime(endDate.year, endDate.month, endDate.day + 1);
    return _sorted('payments', 'date')
        .where((p) {
          final date = DateTime.parse(p['date'] as String);
          return (name == null ||
                  p['customer_name']
                      .toString()
                      .toLowerCase()
                      .contains(name.toLowerCase())) &&
              (startDate == null || !date.isBefore(startDate)) &&
              (end == null || date.isBefore(end));
        })
        .skip(offset)
        .take(limit)
        .toList();
  }

  Future<void> insertCustomer(Map<String, dynamic> data) =>
      _insert('customers', data);
  Future<void> updateCustomer(String id, Map<String, dynamic> data) =>
      _update('customers', id, data);
  Future<void> deleteCustomer(String id) =>
      transaction('eliminar_cliente:$id', (s) {
        if (rowsOf(s, 'loans').any((l) => l['customer_id'].toString() == id)) {
          throw StateError(
              'El cliente tiene préstamos. Conserva su historial.');
        }
        if (rowsOf(s, 'credit_accounts').any((a) => a['customerId'] == id)) {
          throw StateError(
              'El cliente tiene un crédito vinculado. Conserva su historial.');
        }
        s['customers'] = rowsOf(s, 'customers')
          ..removeWhere((c) => c['id'].toString() == id);
      });
  Future<void> insertLoan(Map<String, dynamic> data) => _insert('loans', data);

  Future<void> updateLoan(String id, Map<String, dynamic> data) =>
      _update('loans', id, data);
  Future<void> updateLoanPayment(String id, double amount) =>
      transaction('reconciliar_pagos:$id', (s) {
        positive(amount, 'Total pagado', allowZero: true);
        final total = rowsOf(s, 'payments')
            .where((p) => p['loan_id'].toString() == id)
            .fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());
        if ((amount - total).abs() > 0.001) {
          throw ArgumentError(
              'El total debe coincidir con los pagos registrados.');
        }
        _reconcile(s, id);
      });
  Future<void> deleteLoan(String id) =>
      transaction('eliminar_prestamo:$id', (s) {
        if (rowsOf(s, 'payments').any((p) => p['loan_id'].toString() == id)) {
          throw StateError('El préstamo tiene pagos. Conserva su historial.');
        }
        s['loans'] = rowsOf(s, 'loans')
          ..removeWhere((l) => l['id'].toString() == id);
      });
  void _reconcile(Map<String, dynamic> s, String loanId) {
    final loans = rowsOf(s, 'loans');
    final index = loans.indexWhere((l) => l['id'].toString() == loanId);
    if (index < 0) throw StateError('Préstamo inexistente.');
    loans[index]['amount_paid'] = rowsOf(s, 'payments')
        .where((p) => p['loan_id'].toString() == loanId)
        .fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());
    s['loans'] = loans;
  }

  Future<void> insertPayment(Map<String, dynamic> data) =>
      transaction('registrar_pago:${data['id']}', (s) {
        _putRow(s, 'payments', data);
        _reconcile(s, data['loan_id'].toString());
      });
  Future<void> updatePayment(String id, Map<String, dynamic> data) =>
      transaction('corregir_pago:$id', (s) {
        final old =
            rowsOf(s, 'payments').firstWhere((p) => p['id'].toString() == id);
        _putRow(s, 'payments',
            {...old, ...data, 'id': old['id'], 'loan_id': old['loan_id']},
            replace: true);
        _reconcile(s, old['loan_id'].toString());
      });
  Future<void> deletePayment(String id) => transaction('anular_pago:$id', (s) {
        final rows = rowsOf(s, 'payments');
        final old = rows.firstWhere((p) => p['id'].toString() == id);
        s['payments'] = rows..removeWhere((p) => p['id'].toString() == id);
        _reconcile(s, old['loan_id'].toString());
      });
  Future<void> insertCapitalEntry(Map<String, dynamic> data) =>
      _insert('capital_history', data);
  Future<String?> getSetting(String key) async =>
      (readSnapshot()['settings'] as Map)[key] as String?;
  Future<void> saveSetting(String key, String value) =>
      transaction('ajuste:$key', (s) {
        (s['settings'] as Map)[key] = value;
      });
  Future<void> clearAllUserData() => transaction('reiniciar_datos', (s) {
        if (rowsOf(s, 'credit_accounts').isNotEmpty) {
          throw StateError(
              'Hay créditos vinculados. Conserva sus clientes y exporta un respaldo completo.');
        }
        for (final table in [
          'customers',
          'loans',
          'payments',
          'capital_history'
        ]) {
          s[table] = <dynamic>[];
        }
        s['settings'] = <String, dynamic>{};
      });
  Future<void> importLegacyBackup(Map<String, dynamic> backup) =>
      transaction('importar_respaldo', (s) {
        if (backup['version'] != 1) {
          throw ArgumentError('Versión de respaldo no compatible.');
        }
        for (final table in [
          'customers',
          'loans',
          'payments',
          'capital_history'
        ]) {
          final source = table == 'capital_history' ? 'capitalHistory' : table;
          final items = backup[source];
          if (items is! List) throw ArgumentError('Falta la lista $source.');
          final seen = <String>{};
          for (final raw in items) {
            if (raw is! Map) {
              throw ArgumentError('Registro inválido en $source.');
            }
            final row = Map<String, dynamic>.from(raw);
            for (final pair in {
              'customerId': 'customer_id',
              'initialAmount': 'initial_amount',
              'startDate': 'start_date',
              'incrementType': 'increment_type',
              'incrementValue': 'increment_value',
              'incrementPeriod': 'increment_period',
              'amountPaid': 'amount_paid',
              'accumulateOverdueInterest': 'accumulate_overdue_interest',
              'loanId': 'loan_id',
              'customerName': 'customer_name',
              'createdAt': 'created_at'
            }.entries) {
              if (row.containsKey(pair.key)) row[pair.value] = row[pair.key];
            }
            if (!seen.add(row['id'].toString())) {
              throw ArgumentError('Identificador duplicado en $source.');
            }
            _validate(table, row, s);
            if (!rowsOf(s, table).any((e) => e['id'] == row['id'])) {
              _putRow(s, table, row, validateCash: false);
            }
          }
        }
        for (final loan in rowsOf(s, 'loans')) {
          _reconcile(s, loan['id'].toString());
        }
        if (rowsOf(s, 'capital_history').isEmpty &&
            backup['initialCapital'] != null) {
          positive(backup['initialCapital'], 'Capital', allowZero: true);
          (s['settings'] as Map)['initial_capital'] =
              backup['initialCapital'].toString();
        }
        if (backup['businessName'] is String) {
          (s['settings'] as Map)['business_name'] = backup['businessName'];
        }
      });
  Map<String, dynamic> exportBusinessBackup() => {
        'version': 3,
        'exportedAt': DateTime.now().toIso8601String(),
        'business': readSnapshot(),
      };
  Future<void> restoreBusinessBackup(Map<String, dynamic> backup) =>
      transaction('restaurar_respaldo', (s) {
        if (![2, 3].contains(backup['version']) || backup['business'] is! Map) {
          throw ArgumentError('Respaldo completo incompatible.');
        }
        final incoming = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(backup['business'])) as Map);
        for (final table in [
          'customers',
          'loans',
          'payments',
          'capital_history'
        ]) {
          if (incoming[table] is! List) throw ArgumentError('Falta $table.');
          final seen = <String>{};
          for (final row in rowsOf(incoming, table)) {
            // Historical imports are validated without treating stored loans as new deliveries.
            _validate(table, row, incoming);
            if (!seen.add(row['id'].toString())) {
              throw ArgumentError('Identificador duplicado.');
            }
          }
        }
        if (incoming['settings'] is! Map) {
          throw ArgumentError('Ajustes inválidos.');
        }
        final apps = rowsOf(incoming, 'applications');
        final ids = <String>{};
        for (final a in apps) {
          if (!ids.add(a['id'] as String)) {
            throw ArgumentError('Solicitud duplicada.');
          }
          if (!_users.values.any((u) => (u as Map)['id'] == a['ownerId'])) {
            throw ArgumentError(
                'Falta la cuenta del solicitante. Restaura en la instalación original.');
          }
          final terms =
              CreditTerms.fromMap(Map<String, dynamic>.from(a['terms'] as Map));
          terms.validate();
          FinancialProfile.fromMap(
                  Map<String, dynamic>.from(a['profile'] as Map))
              .validate();
          if (![
            'draft',
            'submitted',
            'compliance',
            'management',
            'approved',
            'rejected',
            'returned'
          ].contains(a['status'])) {
            throw ArgumentError('Estado inválido.');
          }
          if (a['status'] == 'approved' && a['creditLifecycle'] == null) {
            final expected = CreditEngine.schedule(
                    terms, DateTime.parse(a['approvedAt'] as String))
                .map((r) => r.toMap())
                .toList();
            if (jsonEncode(expected) != jsonEncode(a['schedule'])) {
              throw ArgumentError('Plan de cuotas alterado o incompatible.');
            }
            CreditEngine.balances(
                expected,
                rowsOf(incoming, 'credit_payments')
                    .where((p) => p['applicationId'] == a['id'])
                    .toList(),
                (terms.lateFee * 100).round(),
                DateTime.now());
          }
          if (a['creditLifecycle'] != null &&
              (a['creditLifecycle'] != 'awaitingFormalization' ||
                  a['status'] != 'approved')) {
            throw ArgumentError('Ciclo financiero inválido.');
          }
          if (a['creditLifecycle'] == 'awaitingFormalization') {
            final approved = DateTime.parse(a['approvedAt'] as String);
            if (approved.isAfter(DateTime.now()) ||
                jsonEncode(a['quotedSchedule']) !=
                    jsonEncode(CreditEngine.schedule(terms, approved)
                        .map((r) => r.toMap())
                        .toList())) {
              throw ArgumentError('Cotización aprobada alterada.');
            }
          }
        }
        final accounts = rowsOf(incoming, 'credit_accounts');
        final accountIds = <String>{};
        final linkedApplications = <String>{};
        final disbursementReferences = <String>{};
        for (final record in accounts) {
          final app =
              apps.where((a) => a['id'] == record['applicationId']).firstOrNull;
          if (record['id'] is! String ||
              !accountIds.add(record['id'] as String) ||
              !linkedApplications.add(record['applicationId'] as String) ||
              app == null ||
              app['status'] != 'approved' ||
              app['ownerId'] != record['ownerId'] ||
              !rowsOf(incoming, 'customers')
                  .any((c) => c['id'].toString() == record['customerId']) ||
              !['formalized', 'active'].contains(record['status']) ||
              record['termsVersion'] != 1 ||
              record['legacy'] is! bool ||
              record['acceptanceReference'] is! String ||
              (record['acceptanceReference'] as String).trim().length < 5) {
            throw ArgumentError('Crédito vinculado inválido.');
          }
          final terms = CreditTerms.fromMap(
              Map<String, dynamic>.from(record['terms'] as Map));
          if (jsonEncode(terms.toMap()) !=
              jsonEncode(CreditTerms.fromMap(
                      Map<String, dynamic>.from(app['terms'] as Map))
                  .toMap())) {
            throw ArgumentError('Condiciones del crédito alteradas.');
          }
          final formalized = DateTime.parse(record['formalizedAt'] as String);
          if (formalized.isAfter(DateTime.now()) ||
              (record['legacy'] == true) != (app['creditLifecycle'] == null)) {
            throw ArgumentError('Formalización o conciliación inválida.');
          }
          if (record['cashPrincipalCents'] is! int ||
              record['cashPaymentBaselineCents'] is! int ||
              (record['cashPaymentBaselineCents'] as int) < 0) {
            throw ArgumentError('Conciliación de caja inválida.');
          }
          if (record['status'] == 'active') {
            final disbursed = DateTime.parse(record['disbursedAt'] as String);
            if (disbursed.isAfter(DateTime.now()) ||
                (record['legacy'] != true &&
                    disbursed.isBefore(DateTime(
                        formalized.year, formalized.month, formalized.day))) ||
                record['disbursementReference'] is! String ||
                (record['disbursementReference'] as String).trim().length < 3 ||
                !disbursementReferences
                    .add(record['disbursementReference'] as String)) {
              throw ArgumentError('Desembolso inválido.');
            }
            final expected = record['legacy'] == true
                ? app['schedule']
                : CreditEngine.schedule(terms, disbursed)
                    .map((r) => r.toMap())
                    .toList();
            if (jsonEncode(expected) != jsonEncode(record['schedule'])) {
              throw ArgumentError('Plan activo alterado.');
            }
            final openingIncluded = record['legacy'] == true &&
                record['cashAlreadyIncluded'] == true;
            final grossHistoricalPayments = rowsOf(incoming, 'credit_payments')
                .where((p) =>
                    p['applicationId'] == app['id'] &&
                    !DateTime.parse(p['date'] as String).isAfter(formalized))
                .fold<int>(0, (sum, p) => sum + (p['amountCents'] as int));
            if ((record['cashPaymentBaselineCents'] as int) >
                    grossHistoricalPayments ||
                (record['legacy'] == true &&
                    record['cashAlreadyIncluded'] is! bool)) {
              throw ArgumentError('Saldo de apertura inválido.');
            }
            if (record['cashPrincipalCents'] !=
                    (openingIncluded ? 0 : (terms.principal * 100).round()) ||
                (!openingIncluded && record['cashPaymentBaselineCents'] != 0)) {
              throw ArgumentError('Movimiento de desembolso alterado.');
            }
            PortfolioLedger.accountBalance(incoming, record);
          } else if (record['legacy'] == true ||
              rowsOf(record, 'schedule').isNotEmpty ||
              record['cashPrincipalCents'] != 0 ||
              record['cashPaymentBaselineCents'] != 0) {
            throw ArgumentError('Crédito sin desembolso inconsistente.');
          }
        }
        final paymentIds = <String>{};
        final paymentReferences = <String>{};
        for (final p in rowsOf(incoming, 'credit_payments')) {
          if (!ids.contains(p['applicationId']) ||
              !paymentIds.add(p['id'] as String) ||
              p['amountCents'] is! int ||
              (p['amountCents'] as int) <= 0 ||
              DateTime.parse(p['date'] as String).isAfter(DateTime.now())) {
            throw ArgumentError('Pago inválido en el respaldo.');
          }
          final app = apps.firstWhere((a) => a['id'] == p['applicationId']);
          final record = accounts
              .where((a) => a['applicationId'] == p['applicationId'])
              .firstOrNull;
          if (app['status'] != 'approved' ||
              p['reference'] is! String ||
              (p['reference'] as String).trim().length < 3 ||
              (p['voided'] != null && p['voided'] is! bool) ||
              (record != null &&
                  record['status'] == 'active' &&
                  record['legacy'] != true &&
                  DateTime.parse(p['date'] as String).isBefore(
                      DateTime.parse(record['disbursedAt'] as String))) ||
              (app['creditLifecycle'] != null &&
                  record?['status'] != 'active') ||
              (p['accountId'] != null && p['accountId'] != record?['id']) ||
              (p['voided'] != true &&
                  !paymentReferences
                      .add('${p['applicationId']}:${p['reference']}'))) {
            throw ArgumentError(
                'Pago sin crédito activo o referencia duplicada.');
          }
        }
        if (incoming['scoring_rules'] != null) {
          final rules = incoming['scoring_rules'];
          if (rules is! Map ||
              rules['version'] is! int ||
              (rules['version'] as int) < 1 ||
              rules['maxDti'] is! num ||
              !(rules['maxDti'] as num).isFinite ||
              (rules['maxDti'] as num) <= 0 ||
              (rules['maxDti'] as num) > 1) {
            throw ArgumentError('Reglas de evaluación inválidas.');
          }
        }
        for (final key in [
          'customers',
          'loans',
          'payments',
          'capital_history',
          'settings',
          'applications',
          'credit_payments',
          'credit_accounts',
          'scoring_rules'
        ]) {
          if (incoming.containsKey(key)) {
            s[key] = incoming[key];
          } else {
            s.remove(key);
          }
        }
        // Conserva la bitácora de esta instalación y archiva la del respaldo.
        s['restored_audit'] = incoming['audit'] ?? [];
      });
}
