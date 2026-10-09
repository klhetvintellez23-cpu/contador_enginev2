import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../models/loan_calculator.dart';
import '../models/payment.dart';
import '../models/capital_entry.dart';
import '../models/insights.dart';
import '../models/backup_preview.dart';
import '../services/local_database_service.dart';

import '../services/local_cache_service.dart';
import '../services/notification_service.dart';
import '../utils/export_helper.dart';

class DebtProvider with ChangeNotifier {
  List<Customer> _customers = [];
  List<LoanTransaction> _allLoans = [];
  List<Payment> _allPayments = [];
  List<CapitalEntry> _capitalHistory = [];
  List<Payment> _paginatedPayments = [];
  List<Customer> _paginatedCustomers = [];
  double _initialCapital = 0.0;
  String? _businessName;
  String? _businessLogoPath;
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _isFetchingMoreCustomers = false;
  bool _hasMorePayments = true;
  bool _hasMoreCustomers = true;
  int _currentOffset = 0;
  int _currentCustomerOffset = 0;
  final int _pageSize = 5;
  double _totalReceivable = 0.0;
  double _activeCapital = 0.0;
  double _moneyInHand = 0.0;
  double _totalCollected = 0.0;
  double _recoveredCapital = 0.0;
  double _realizedProfit = 0.0;
  double _projectedProfit = 0.0;

  List<Customer> get customers => _customers;
  List<Customer> get paginatedCustomers => _paginatedCustomers;
  List<LoanTransaction> get allLoans => _allLoans;
  List<Payment> get allPayments => _allPayments;
  List<CapitalEntry> get capitalHistory => _capitalHistory;
  List<Payment> get paginatedPayments => _paginatedPayments;
  double get initialCapital => _initialCapital;
  String? get businessName => _businessName;
  String? get businessLogoPath => _businessLogoPath;
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get isFetchingMoreCustomers => _isFetchingMoreCustomers;
  bool get hasMorePayments => _hasMorePayments;
  bool get hasMoreCustomers => _hasMoreCustomers;

  final LocalDatabaseService _database = LocalDatabaseService();
  final LocalCacheService _cache = LocalCacheService();
  final Uuid _uuid = const Uuid();
  bool get isOffline => false;
  int get pendingCount => _cache.pendingCount;
  bool _isFetching = false;

  DebtProvider() {
    _businessLogoPath = _cache.readBusinessLogoPath();
  }

  LoanTransaction? getLoanById(dynamic id) {
    try {
      return _allLoans.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Customer? getCustomerById(dynamic id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ==================== Cálculo de préstamos ====================

  /// Agrupa todos los cobros por préstamo, para calcular varios préstamos
  /// sin recorrer la lista completa de pagos una y otra vez.
  Map<dynamic, List<Payment>> _paymentsByLoan() {
    final map = <dynamic, List<Payment>>{};
    for (final p in _allPayments) {
      (map[p.loanId] ??= []).add(p);
    }
    return map;
  }

  /// Estado financiero de un préstamo (capital pendiente, interés pendiente,
  /// desglose de cada cobro, etc.), calculado sobre el saldo de capital.
  /// Fuente única de verdad para toda la app.
  LoanAccountState loanState(LoanTransaction loan, {DateTime? asOf}) {
    return LoanCalculator.compute(
      loan,
      _allPayments.where((p) => p.loanId == loan.id),
      asOf: asOf,
    );
  }

  /// Deuda total pendiente de un préstamo (capital + interés pendiente).
  double currentDebt(LoanTransaction loan) => loanState(loan).totalDebt;

  /// Recalcula métricas y refresca la UI tras cambiar una preferencia que
  /// afecta el cálculo del interés (p. ej. la política de interés vencido),
  /// sin necesidad de volver a consultar la red.
  void refreshCalculations() {
    _recalculateMetrics();
    notifyListeners();
  }

  // ==================== Mora (clientes atrasados) ====================

  /// Fecha del último movimiento del préstamo: el cobro más reciente, o la
  /// fecha de inicio si todavía no registra ningún cobro.
  DateTime lastActivityDate(LoanTransaction loan) {
    DateTime? latest;
    for (final p in _allPayments) {
      if (p.loanId != loan.id) continue;
      if (latest == null || p.date.isAfter(latest)) latest = p.date;
    }
    return latest ?? loan.startDate;
  }

  /// Un préstamo se considera atrasado cuando ya pasó más tiempo que su
  /// propio ciclo (diario/semanal/quincenal/mensual) desde el último cobro
  /// registrado, y todavía tiene saldo pendiente. Ordenados por más
  /// urgente primero (más tiempo sin cobro).
  List<LoanTransaction> get overdueLoans {
    final now = DateTime.now();
    final graceDays = _cache.overdueGraceDays;
    final overdue = _allLoans.where((loan) {
      if (currentDebt(loan) <= 0.01) return false;
      final due = LoanCalculator.nextUnpaidDueDate(loan, loanState(loan));
      return now.isAfter(due.add(Duration(days: graceDays)));
    }).toList();
    overdue.sort((a, b) => lastActivityDate(a).compareTo(lastActivityDate(b)));
    return overdue;
  }

  int get overdueCount => overdueLoans.length;

  // ==================== Cobros de hoy ====================

  /// Préstamos que probablemente toca cobrar hoy: ya atrasados, que
  /// cumplieron su ciclo hoy, o que lo cumplen mañana (solo para ciclos de
  /// más de un día, como aviso anticipado).
  List<CollectionForecastItem> get todaysCollections {
    final now = DateTime.now();
    final graceDays = _cache.overdueGraceDays;
    final items = <CollectionForecastItem>[];

    for (final loan in _allLoans) {
      final state = loanState(loan);
      final debt = state.totalDebt;
      if (debt <= 0.01) continue;

      final customer = getCustomerById(loan.customerId);
      if (customer == null) continue;

      final due = LoanCalculator.nextUnpaidDueDate(loan, state);
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      final untilDue = dueDay.difference(today).inDays;
      final daysSince = now.difference(lastActivityDate(loan)).inDays;

      CollectionStatus? status;
      if (untilDue < -graceDays) {
        status = CollectionStatus.overdue;
      } else if (untilDue <= 0) {
        status = CollectionStatus.dueToday;
      } else if (untilDue == 1) {
        status = CollectionStatus.upcoming;
      }
      if (status == null) continue;

      // Se sugiere cobrar al menos el interés del período (calculado sobre el
      // capital pendiente) más lo que quede de interés atrasado.
      final perPeriod = state.pendingInterest > 0
          ? state.pendingInterest
          : LoanCalculator.perPeriodInterest(loan, state.outstandingCapital);
      final suggested =
          perPeriod > 0 ? (perPeriod < debt ? perPeriod : debt) : debt;

      items.add(CollectionForecastItem(
        customer: customer,
        loan: loan,
        suggestedAmount: suggested,
        pendingBalance: debt,
        daysSinceLastPayment: daysSince,
        status: status,
      ));
    }

    const statusOrder = {
      CollectionStatus.overdue: 0,
      CollectionStatus.dueToday: 1,
      CollectionStatus.upcoming: 2,
    };
    items.sort((a, b) {
      final cmp = statusOrder[a.status]!.compareTo(statusOrder[b.status]!);
      if (cmp != 0) return cmp;
      return b.daysSinceLastPayment.compareTo(a.daysSinceLastPayment);
    });

    return items;
  }

  // ==================== Confianza del cliente ====================

  /// Puntaje 0-100 calculado localmente a partir de préstamos, pagos y
  /// atrasos existentes: no depende de ninguna tabla nueva. Arranca en una
  /// base neutral y suma/resta según historial de cumplimiento.
  double trustScoreForCustomer(dynamic customerId) {
    final loans = getLoansByCustomer(customerId);
    if (loans.isEmpty) return 60.0;

    double score = 60.0;

    final completedLoans =
        loans.where((l) => currentDebt(l) <= 0.01 && l.amountPaid > 0).length;
    score += completedLoans.clamp(0, 5) * 5; // hasta +25

    final overdueForCustomer =
        overdueLoans.where((l) => l.customerId == customerId).length;
    score -= overdueForCustomer * 20;

    final now = DateTime.now();
    final graceDays = _cache.overdueGraceDays;
    final activeLoans = loans.where((l) => currentDebt(l) > 0.01);
    for (final loan in activeLoans) {
      final periodLen = loan.incrementPeriod.lengthInDays;
      final daysSince = now.difference(lastActivityDate(loan)).inDays;
      if (daysSince <= periodLen + graceDays) {
        score += 3; // al día dentro de su propio ciclo
      }
    }

    if (_totalReceivable > 0) {
      final pendingForCustomer = loans.fold(0.0, (sum, l) {
        final d = currentDebt(l);
        return sum + (d > 0 ? d : 0);
      });
      final share = pendingForCustomer / _totalReceivable;
      if (share > 0.3) {
        score -= 20;
      } else if (share > 0.15) {
        score -= 10;
      }
    }

    return score.clamp(0, 100);
  }

  TrustLevel trustLevelForCustomer(dynamic customerId) {
    final score = trustScoreForCustomer(customerId);
    if (score >= 80) return TrustLevel.excellent;
    if (score >= 60) return TrustLevel.good;
    if (score >= 40) return TrustLevel.regular;
    return TrustLevel.risky;
  }

  // ==================== Alertas de capital ====================

  String _fmt(double v) => '\$${v.toStringAsFixed(2)}';

  /// Alertas visuales y accionables sobre el estado del capital/cartera,
  /// recalculadas en el momento a partir de las métricas ya existentes.
  List<CapitalAlert> get capitalAlerts {
    final alerts = <CapitalAlert>[];

    final lowCapitalThreshold =
        _initialCapital > 0 ? (_initialCapital * 0.05).clamp(20, 500) : 50.0;
    if (_moneyInHand < lowCapitalThreshold) {
      alerts.add(CapitalAlert(
        type: CapitalAlertType.lowCapital,
        severity: CapitalAlertSeverity.critical,
        title: 'Capital bajo',
        message:
            'Tienes ${_fmt(_moneyInHand)} disponible. Evita nuevos préstamos grandes.',
      ));
    }

    if (_initialCapital > 0 && _activeCapital > _initialCapital * 0.85) {
      final pct = (_activeCapital / _initialCapital * 100).round();
      alerts.add(CapitalAlert(
        type: CapitalAlertType.overLent,
        severity: CapitalAlertSeverity.warning,
        title: 'Capital muy comprometido',
        message:
            'Ya tienes prestado el $pct% de tu capital. Espera recuperaciones antes de prestar más.',
      ));
    }

    if (_totalReceivable > 0) {
      final debtByCustomer = <dynamic, double>{};
      for (final loan in _allLoans) {
        final d = currentDebt(loan);
        if (d <= 0) continue;
        debtByCustomer[loan.customerId] =
            (debtByCustomer[loan.customerId] ?? 0) + d;
      }
      if (debtByCustomer.isNotEmpty) {
        final topEntry =
            debtByCustomer.entries.reduce((a, b) => a.value > b.value ? a : b);
        final share = topEntry.value / _totalReceivable;
        if (share > 0.3) {
          final customer = getCustomerById(topEntry.key);
          final pct = (share * 100).round();
          alerts.add(CapitalAlert(
            type: CapitalAlertType.riskConcentration,
            severity: CapitalAlertSeverity.warning,
            title: 'Riesgo concentrado',
            message:
                '${customer?.name ?? "Un cliente"} representa el $pct% de la cartera pendiente.',
            relatedCustomerId: topEntry.key,
          ));
        }
      }
    }

    final activeLoanCount =
        _allLoans.where((l) => currentDebt(l) > 0.01).length;
    final overdue = overdueLoans;
    if (activeLoanCount > 0) {
      final overdueShare = overdue.length / activeLoanCount;
      if (overdue.length >= 5 || overdueShare > 0.3) {
        alerts.add(CapitalAlert(
          type: CapitalAlertType.manyOverdue,
          severity: CapitalAlertSeverity.critical,
          title: 'Muchos clientes atrasados',
          message:
              '${overdue.length} préstamo(s) atrasado(s) — ${(overdueShare * 100).round()}% de tu cartera activa.',
        ));
      }
    }

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final thisWeek = _allPayments
        .where((p) => p.date.isAfter(weekAgo))
        .fold(0.0, (s, p) => s + p.amount);
    final lastWeek = _allPayments
        .where((p) => p.date.isAfter(twoWeeksAgo) && p.date.isBefore(weekAgo))
        .fold(0.0, (s, p) => s + p.amount);
    if (lastWeek > 0 && thisWeek < lastWeek * 0.5) {
      alerts.add(CapitalAlert(
        type: CapitalAlertType.lowWeeklyRecovery,
        severity: CapitalAlertSeverity.info,
        title: 'Recuperación baja esta semana',
        message:
            'Cobraste ${_fmt(thisWeek)} esta semana vs ${_fmt(lastWeek)} la semana pasada.',
      ));
    }

    return alerts;
  }

  // ==================== Cierre del día ====================

  /// Resumen de lo ocurrido hoy: cobros, préstamos nuevos y capital
  /// entregado desde la medianoche. El interés cobrado se calcula con el
  /// desglose real de cada cobro (interés pagado antes que capital).
  DailyClosingSummary get dailyClosing {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final paymentsToday =
        _allPayments.where((p) => !p.date.isBefore(todayStart)).toList();
    final totalCollectedToday = paymentsToday.fold(0.0, (s, p) => s + p.amount);

    final loansToday =
        _allLoans.where((l) => !l.startDate.isBefore(todayStart)).toList();
    final capitalDeliveredToday =
        loansToday.fold(0.0, (s, l) => s + l.initialAmount);

    final overdueCustomerIds = overdueLoans.map((l) => l.customerId).toSet();

    // Interés cobrado hoy = suma de la porción de interés de cada cobro
    // registrado hoy, según el desglose real del préstamo.
    final byLoan = _paymentsByLoan();
    double interestCollectedToday = 0;
    for (final loan in _allLoans) {
      final loanPayments = byLoan[loan.id];
      if (loanPayments == null) continue;
      final state = LoanCalculator.compute(loan, loanPayments);
      for (final b in state.breakdowns) {
        if (!b.payment.date.isBefore(todayStart)) {
          interestCollectedToday += b.toInterest;
        }
      }
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final reportBuffer = StringBuffer()
      ..writeln('📊 Cierre del día — $dateStr');
    if (_businessName != null && _businessName!.isNotEmpty) {
      reportBuffer.writeln(_businessName);
    }
    reportBuffer
      ..writeln('')
      ..writeln(
          'Cobrado hoy: ${_fmt(totalCollectedToday)} (${paymentsToday.length} pago(s))')
      ..writeln('Préstamos nuevos: ${loansToday.length}')
      ..writeln('Capital entregado: ${_fmt(capitalDeliveredToday)}')
      ..writeln('Clientes atrasados: ${overdueCustomerIds.length}')
      ..writeln('Interés/ganancia cobrada: ${_fmt(interestCollectedToday)}');

    return DailyClosingSummary(
      totalCollectedToday: totalCollectedToday,
      paymentsCountToday: paymentsToday.length,
      newLoansToday: loansToday.length,
      capitalDeliveredToday: capitalDeliveredToday,
      overdueCustomersCount: overdueCustomerIds.length,
      estimatedInterestToday: interestCollectedToday,
      reportText: reportBuffer.toString().trim(),
    );
  }

  // ==================== Sincronización ====================

  /// Persiste directamente en la base del dispositivo.
  Future<void> _writeOrQueue(String type, Map<String, dynamic> args) async {
    await _replayMutation(type, args);
  }

  Future<void> _replayMutation(String type, Map<String, dynamic> args) async {
    switch (type) {
      case 'insertCustomer':
        await _database.insertCustomer(Map<String, dynamic>.from(args['data']));
        break;
      case 'updateCustomer':
        await _database.updateCustomer(
            args['id'] as String, Map<String, dynamic>.from(args['data']));
        break;
      case 'deleteCustomer':
        await _database.deleteCustomer(args['id'] as String);
        break;
      case 'insertLoan':
        await _database.insertLoan(Map<String, dynamic>.from(args['data']));
        break;
      case 'updateLoan':
        await _database.updateLoan(
            args['id'] as String, Map<String, dynamic>.from(args['data']));
        break;
      case 'updateLoanPayment':
        await _database.updateLoanPayment(
            args['loanId'] as String, (args['amountPaid'] as num).toDouble());
        break;
      case 'insertPayment':
        await _database.insertPayment(Map<String, dynamic>.from(args['data']));
        break;
      case 'deletePayment':
        await _database.deletePayment(args['id'] as String);
        break;
      case 'updatePayment':
        await _database.updatePayment(
            args['id'] as String, Map<String, dynamic>.from(args['data']));
        break;
      case 'deleteLoan':
        await _database.deleteLoan(args['id'] as String);
        break;
      case 'insertCapitalEntry':
        await _database
            .insertCapitalEntry(Map<String, dynamic>.from(args['data']));
        break;
      case 'saveSetting':
        await _database.saveSetting(
            args['key'] as String, args['value'] as String);
        break;
    }
  }

  // ==================== Carga de datos ====================

  Future<void> fetchAll() async {
    if (_database.currentUser?.role != UserRole.manager) return;
    _businessLogoPath = _cache.readBusinessLogoPath();
    if (_isFetching) return; // Evitar recargas simultáneas
    _isFetching = true;
    _isLoading = true;
    notifyListeners();

    bool loadedFromDatabase = false;
    if (!isOffline) {
      try {
        final results = await Future.wait([
          _database.getSetting('initial_capital'),
          _database.getSetting('business_name'),
          _database.getCustomers(),
          _database.getAllLoans(),
          _database.getAllPayments(),
          _database.getCapitalHistory(),
        ]);

        final capString = results[0] as String?;
        final businessNameString = results[1] as String?;
        final customerMaps = results[2] as List<Map<String, dynamic>>;
        final loanMaps = results[3] as List<Map<String, dynamic>>;
        final paymentMaps = results[4] as List<Map<String, dynamic>>;
        final capitalMaps = results[5] as List<Map<String, dynamic>>;

        _capitalHistory =
            capitalMaps.map((m) => CapitalEntry.fromMap(m)).toList();
        _customers = customerMaps.map((m) => Customer.fromMap(m)).toList();
        _allLoans = loanMaps.map((m) => LoanTransaction.fromMap(m)).toList();
        _allPayments = paymentMaps.map((m) => Payment.fromMap(m)).toList();

        _initialCapital = _capitalHistory.isNotEmpty
            ? _capitalHistory.fold(0.0, (sum, e) => sum + e.amount)
            : (double.tryParse(capString ?? '0') ?? 0.0);
        if (businessNameString != null && businessNameString.isNotEmpty) {
          _businessName = businessNameString;
        }

        await _cache.replaceMirror('customers', customerMaps);
        await _cache.replaceMirror('loans', loanMaps);
        await _cache.replaceMirror('payments', paymentMaps);
        await _cache.replaceMirror('capital_history', capitalMaps);
        await _cache.saveInitialCapitalFallback(_initialCapital);
        if (_businessName != null) {
          await _cache.saveBusinessNameFallback(_businessName!);
        }

        loadedFromDatabase = true;
      } catch (e) {
        debugPrint('fetchAll: fallo de lectura, se usa el espejo local ($e)');
      }
    }

    if (!loadedFromDatabase) {
      _customers = _cache
          .readMirror('customers')
          .map((m) => Customer.fromMap(m))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _allLoans = _cache
          .readMirror('loans')
          .map((m) => LoanTransaction.fromMap(m))
          .toList();
      _allPayments =
          _cache.readMirror('payments').map((m) => Payment.fromMap(m)).toList();
      _capitalHistory = _cache
          .readMirror('capital_history')
          .map((m) => CapitalEntry.fromMap(m))
          .toList();
      _initialCapital = _capitalHistory.isNotEmpty
          ? _capitalHistory.fold(0.0, (sum, e) => sum + e.amount)
          : (_cache.readInitialCapitalFallback() ?? 0.0);
      _businessName ??= _cache.readBusinessNameFallback();
    }

    _recalculateMetrics();

    _currentOffset = 0;
    _currentCustomerOffset = 0;
    _hasMorePayments = true;
    _hasMoreCustomers = true;

    if (loadedFromDatabase) {
      _paginatedPayments = [];
      _paginatedCustomers = [];
      await fetchCustomersNextPage(reset: true, silent: true);
      await fetchPaymentsNextPage(reset: true, silent: true);
    } else {
      // Sin red: paginamos en memoria sobre lo que ya tenemos cacheado.
      _fetchCustomersNextPageOffline(reset: true);
      _fetchPaymentsNextPageOffline(reset: true);
    }

    _isLoading = false;
    _isFetching = false;
    notifyListeners();

    if (_cache.dailyReminderEnabled) {
      unawaited(NotificationService()
          .scheduleDailyCollectionsReminder(todaysCollections.length));
    } else {
      unawaited(NotificationService().cancelDailyReminder());
    }
  }

  // ==================== Mutaciones optimistas ====================

  Future<void> addCustomer(String name, String? phone, String? cedula) async {
    final id = _uuid.v4();
    final customer = Customer(id: id, name: name, phone: phone, cedula: cedula);
    final data = customer.toMap(snakeCase: true);

    _customers = [..._customers, customer]
      ..sort((a, b) => a.name.compareTo(b.name));
    _paginatedCustomers = [customer, ..._paginatedCustomers];
    await _cache.upsertMirrorRow('customers', data);
    notifyListeners();

    try {
      await _writeOrQueue('insertCustomer', {'data': data});
    } finally {
      await fetchAll();
    }
  }

  Future<void> updateCustomer(
      dynamic id, String name, String? phone, String? cedula) async {
    final data = {'name': name, 'phone': phone, 'cedula': cedula};

    Customer patch(Customer c) => Customer(
        id: c.id,
        name: name,
        phone: phone,
        cedula: cedula,
        photoPath: c.photoPath);
    _customers = _customers.map((c) => c.id == id ? patch(c) : c).toList();
    _paginatedCustomers =
        _paginatedCustomers.map((c) => c.id == id ? patch(c) : c).toList();
    await _cache.mergeMirrorRow('customers', id.toString(), data);
    notifyListeners();

    try {
      await _writeOrQueue(
          'updateCustomer', {'id': id.toString(), 'data': data});
    } finally {
      await fetchAll();
    }
  }

  Future<void> deleteCustomer(String? id) async {
    if (id == null) return;

    _customers = _customers.where((c) => c.id.toString() != id).toList();
    _paginatedCustomers =
        _paginatedCustomers.where((c) => c.id.toString() != id).toList();
    await _cache.removeMirrorRow('customers', id);
    notifyListeners();

    try {
      await _writeOrQueue('deleteCustomer', {'id': id});
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      rethrow;
    } finally {
      await fetchAll();
    }
  }

  Future<void> addLoan({
    required dynamic customerId,
    required String title,
    required double initialAmount,
    required IncrementType incrementType,
    required double incrementValue,
    required DateTime startDate,
    IncrementPeriod incrementPeriod = IncrementPeriod.daily,
    bool accumulateOverdueInterest = true,
  }) async {
    LocalDatabaseService.positive(initialAmount, 'Monto');
    LocalDatabaseService.positive(incrementValue, 'Tasa', allowZero: true);
    if (initialAmount > moneyInHand) {
      throw ArgumentError('Capital insuficiente.');
    }
    final id = _uuid.v4();
    final loan = LoanTransaction(
      id: id,
      customerId: customerId,
      title: title,
      initialAmount: initialAmount,
      startDate: startDate,
      incrementType: incrementType,
      incrementValue: incrementValue,
      incrementPeriod: incrementPeriod,
      accumulateOverdueInterest: accumulateOverdueInterest,
    );
    final data = loan.toMap(snakeCase: true);

    _allLoans = [..._allLoans, loan];
    await _cache.upsertMirrorRow('loans', data);
    _recalculateMetrics();
    notifyListeners();

    try {
      await _writeOrQueue('insertLoan', {'data': data});
    } finally {
      await fetchAll();
    }
  }

  /// Cambia la política de interés vencido de UN préstamo concreto
  /// (Opción B = acumular / Opción A = no acumular). No afecta a los demás.
  Future<void> setAccumulateOverdueInterest(dynamic loanId, bool value) async {
    final current = _allLoans.firstWhere((l) => l.id == loanId);
    if (current.accumulateOverdueInterest == value) return;

    _allLoans = _allLoans.map((l) {
      if (l.id != loanId) return l;
      return LoanTransaction(
        id: l.id,
        customerId: l.customerId,
        title: l.title,
        initialAmount: l.initialAmount,
        startDate: l.startDate,
        incrementType: l.incrementType,
        incrementValue: l.incrementValue,
        incrementPeriod: l.incrementPeriod,
        accumulateOverdueInterest: value,
        amountPaid: l.amountPaid,
      );
    }).toList();

    await _cache.mergeMirrorRow(
        'loans', loanId.toString(), {'accumulate_overdue_interest': value});
    _recalculateMetrics();
    notifyListeners();

    try {
      await _writeOrQueue('updateLoan', {
        'id': loanId.toString(),
        'data': {'accumulate_overdue_interest': value},
      });
    } finally {
      await fetchAll();
    }
  }

  Future<Payment> registerPayment(
      dynamic loanId, double paymentAmount, String customerName) async {
    LocalDatabaseService.positive(paymentAmount, 'Pago');
    final loan = _allLoans.firstWhere((l) => l.id == loanId);
    if (paymentAmount > currentDebt(loan) + 0.001) {
      throw ArgumentError('El pago supera el saldo pendiente.');
    }
    final payment = Payment(
        id: _uuid.v4(),
        loanId: loanId,
        amount: paymentAmount,
        date: DateTime.now(),
        customerName: customerName);
    await _database.insertPayment(payment.toMap(snakeCase: true));
    await fetchAll();
    return payment;
  }

  Future<void> deletePayment(
      dynamic paymentId, dynamic loanId, double amount) async {
    await _database.deletePayment(paymentId.toString());
    await fetchAll();
  }

  Future<void> editPayment(
    dynamic paymentId,
    dynamic loanId, {
    required double oldAmount,
    required double newAmount,
    required DateTime newDate,
  }) async {
    LocalDatabaseService.positive(newAmount, 'Pago');
    final loan = _allLoans.firstWhere((l) => l.id == loanId);
    if (newDate.isBefore(loan.startDate) || newDate.isAfter(DateTime.now())) {
      throw ArgumentError('Fecha fuera del préstamo.');
    }
    final remaining = LoanCalculator.compute(loan,
        _allPayments.where((p) => p.loanId == loanId && p.id != paymentId),
        asOf: DateTime.now());
    if (newAmount > remaining.totalDebt + 0.001) {
      throw ArgumentError('El pago supera el saldo pendiente.');
    }
    await _database.updatePayment(paymentId.toString(),
        {'amount': newAmount, 'date': newDate.toIso8601String()});
    await fetchAll();
  }

  /// Elimina un préstamo completo junto con todos sus cobros registrados.
  Future<void> deleteLoan(dynamic loanId) async {
    final payments = _allPayments.where((p) => p.loanId == loanId).toList();

    _allLoans = _allLoans.where((l) => l.id != loanId).toList();
    _allPayments = _allPayments.where((p) => p.loanId != loanId).toList();
    _paginatedPayments =
        _paginatedPayments.where((p) => p.loanId != loanId).toList();
    await _cache.removeMirrorRow('loans', loanId.toString());
    for (final p in payments) {
      await _cache.removeMirrorRow('payments', p.id.toString());
    }
    _recalculateMetrics();
    notifyListeners();

    try {
      await _writeOrQueue('deleteLoan', {'id': loanId.toString()});
    } finally {
      await fetchAll();
    }
  }

  Future<void> addCapitalEntry(double amount, String note) async {
    final id = _uuid.v4();
    final entry = CapitalEntry(
        id: id, amount: amount, note: note, createdAt: DateTime.now());
    final data = entry.toMap(snakeCase: true);

    _capitalHistory = [entry, ..._capitalHistory];
    _initialCapital += amount;
    await _cache.upsertMirrorRow('capital_history', data);
    await _cache.saveInitialCapitalFallback(_initialCapital);
    _recalculateMetrics();
    notifyListeners();

    try {
      await _writeOrQueue('insertCapitalEntry', {'data': data});
    } finally {
      await fetchAll();
    }
  }

  Future<void> fetchPaymentsNextPage({
    bool reset = false,
    bool silent = false,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (isOffline) {
      _fetchPaymentsNextPageOffline(
          reset: reset, name: name, startDate: startDate, endDate: endDate);
      return;
    }

    if (reset) {
      _currentOffset = 0;
      _paginatedPayments = [];
      _hasMorePayments = true;
      if (!silent) {
        _isLoading = true;
        notifyListeners();
      }
    } else {
      if (!_hasMorePayments || _isFetchingMore) return;
      _isFetchingMore = true;
      if (!silent) notifyListeners();
    }

    try {
      final newMaps = await _database.getPaymentsPaginated(
        name: name,
        startDate: startDate,
        endDate: endDate,
        limit: _pageSize,
        offset: _currentOffset,
      );

      final newPayments = newMaps.map((m) => Payment.fromMap(m)).toList();

      if (reset) {
        _paginatedPayments = newPayments;
        _isLoading = false;
      } else {
        _paginatedPayments.addAll(newPayments);
        _isFetchingMore = false;
      }

      _hasMorePayments = newPayments.length == _pageSize;
      _currentOffset += newPayments.length;
    } catch (e) {
      debugPrint('Error fetching paginated payments: $e');
      _isLoading = false;
      _isFetchingMore = false;
      // Puede que la interfaz de red esté "activa" pero sin internet real:
      // caemos a la paginación en memoria en vez de dejar la lista colgada.
      _fetchPaymentsNextPageOffline(
          reset: reset, name: name, startDate: startDate, endDate: endDate);
      return;
    }

    if (!silent) notifyListeners();
  }

  void _fetchPaymentsNextPageOffline({
    bool reset = false,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (reset) {
      _currentOffset = 0;
      _paginatedPayments = [];
      _hasMorePayments = true;
    }

    final filtered = _allPayments.where((p) {
      if (name != null &&
          name.isNotEmpty &&
          !(p.customerName ?? '').toLowerCase().contains(name.toLowerCase())) {
        return false;
      }
      if (startDate != null && p.date.isBefore(startDate)) return false;
      if (endDate != null) {
        final endOfDay =
            DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (p.date.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final nextChunk = filtered.skip(_currentOffset).take(_pageSize).toList();
    _paginatedPayments =
        reset ? nextChunk : [..._paginatedPayments, ...nextChunk];
    _currentOffset += nextChunk.length;
    _hasMorePayments = _currentOffset < filtered.length;
    _isLoading = false;
    _isFetchingMore = false;
    notifyListeners();
  }

  Future<void> fetchCustomersNextPage({
    bool reset = false,
    bool silent = false,
    String? search,
  }) async {
    if (isOffline) {
      _fetchCustomersNextPageOffline(reset: reset, search: search);
      return;
    }

    if (reset) {
      _currentCustomerOffset = 0;
      _paginatedCustomers = [];
      _hasMoreCustomers = true;
      if (!silent) notifyListeners();
    } else {
      if (!_hasMoreCustomers || _isFetchingMoreCustomers) return;
      _isFetchingMoreCustomers = true;
      if (!silent) notifyListeners();
    }

    try {
      final newMaps = await _database.getCustomersPaginated(
        limit: _pageSize,
        offset: _currentCustomerOffset,
        searchQuery: search,
      );

      final newCustomers = newMaps.map((m) => Customer.fromMap(m)).toList();

      if (reset) {
        _paginatedCustomers = newCustomers;
      } else {
        _paginatedCustomers.addAll(newCustomers);
        _isFetchingMoreCustomers = false;
      }

      _hasMoreCustomers = newCustomers.length == _pageSize;
      _currentCustomerOffset += newCustomers.length;
    } catch (e) {
      debugPrint('Error fetching paginated customers: $e');
      _isFetchingMoreCustomers = false;
      _fetchCustomersNextPageOffline(reset: reset, search: search);
      return;
    }

    notifyListeners();
  }

  void _fetchCustomersNextPageOffline({bool reset = false, String? search}) {
    if (reset) {
      _currentCustomerOffset = 0;
      _paginatedCustomers = [];
      _hasMoreCustomers = true;
    }

    final filtered = _customers.where((c) {
      if (search != null &&
          search.isNotEmpty &&
          !c.name.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final nextChunk =
        filtered.skip(_currentCustomerOffset).take(_pageSize).toList();
    _paginatedCustomers =
        reset ? nextChunk : [..._paginatedCustomers, ...nextChunk];
    _currentCustomerOffset += nextChunk.length;
    _hasMoreCustomers = _currentCustomerOffset < filtered.length;
    _isFetchingMoreCustomers = false;
    notifyListeners();
  }

  double get totalReceivable {
    return _totalReceivable;
  }

  List<LoanTransaction> getLoansByCustomer(dynamic customerId) {
    return _allLoans.where((l) => l.customerId == customerId).toList();
  }

  Future<void> setInitialCapital(double amount) async {
    final diff = amount - _initialCapital;
    if (diff.abs() < 0.01) return; // No hay cambio real
    await addCapitalEntry(diff, "Ajuste manual de capital");
    await _writeOrQueue(
        'saveSetting', {'key': 'initial_capital', 'value': amount.toString()});
  }

  /// Nombre del negocio/prestamista: firma los comprobantes de WhatsApp en
  /// vez del genérico "Contador Engine".
  Future<void> setBusinessName(String name) async {
    final trimmed = name.trim();
    _businessName = trimmed;
    await _cache.saveBusinessNameFallback(trimmed);
    notifyListeners();
    await _writeOrQueue(
        'saveSetting', {'key': 'business_name', 'value': trimmed});
  }

  /// Logo del negocio: se guarda solo en este dispositivo (no viaja a
  /// la base local), así que no hace falta pensar en sincronización ni en subir
  /// el archivo a ningún lado.
  Future<void> setBusinessLogoPath(String? path) async {
    _businessLogoPath = path;
    await _cache.saveBusinessLogoPath(path);
    notifyListeners();
  }

  double get activeCapital {
    return _activeCapital;
  }

  double get moneyInHand {
    return _moneyInHand;
  }

  double get totalCollected {
    return _totalCollected;
  }

  double get recoveredCapital {
    return _recoveredCapital;
  }

  double get realizedProfit {
    return _realizedProfit;
  }

  double get projectedProfit {
    return _projectedProfit;
  }

  double _sumPaymentsSince(DateTime since) {
    return _allPayments
        .where((p) => !p.date.isBefore(since))
        .fold(0.0, (s, p) => s + p.amount);
  }

  /// Dinero recuperado (cobrado) hoy/esta semana/este mes, para el
  /// dashboard de ganancias reales.
  double get recoveredToday {
    final now = DateTime.now();
    return _sumPaymentsSince(DateTime(now.year, now.month, now.day));
  }

  double get recoveredThisWeek {
    final now = DateTime.now();
    return _sumPaymentsSince(now.subtract(const Duration(days: 7)));
  }

  double get recoveredThisMonth {
    final now = DateTime.now();
    return _sumPaymentsSince(DateTime(now.year, now.month, 1));
  }

  Future<String?> exportData() async {
    return await ExportHelper.exportDebtsToCSV(
      _customers,
      _allLoans,
      _allPayments,
      _capitalHistory,
      _initialCapital,
    );
  }

  Future<String?> exportPDF() async {
    return await ExportHelper.exportDebtsToPDF(
      _customers,
      _allLoans,
      _allPayments,
      _initialCapital,
      _businessName,
    );
  }

  Future<String?> exportBackup() async {
    return await ExportHelper.exportBackupToJSON(
      _customers,
      _allLoans,
      _allPayments,
      _capitalHistory,
      _initialCapital,
      _businessName,
    );
  }

  // ==================== Importar respaldo ====================

  /// true si el mapa decodificado tiene la forma de un respaldo generado
  /// por [exportBackup] (ver ExportHelper.exportBackupToJSON): al menos una
  /// de las listas esperadas presente y con el tipo correcto.
  bool isValidBackupData(Map<String, dynamic> data) {
    const keys = ['customers', 'loans', 'payments', 'capitalHistory'];
    if (!keys.any(data.containsKey)) return false;
    for (final key in keys) {
      if (data.containsKey(key) && data[key] is! List) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _listFrom(Map<String, dynamic> data, String key) {
    final raw = data[key] as List?;
    if (raw == null) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  /// Cuenta cuántos registros del respaldo son nuevos vs ya existentes
  /// localmente (por id), para mostrar el resumen antes de confirmar.
  BackupPreview previewBackup(Map<String, dynamic> data) {
    final existingCustomerIds = _customers.map((c) => c.id.toString()).toSet();
    final existingLoanIds = _allLoans.map((l) => l.id.toString()).toSet();
    final existingPaymentIds = _allPayments.map((p) => p.id.toString()).toSet();
    final existingCapitalIds =
        _capitalHistory.map((e) => e.id.toString()).toSet();

    final customers = _listFrom(data, 'customers');
    final loans = _listFrom(data, 'loans');
    final payments = _listFrom(data, 'payments');
    final capitalEntries = _listFrom(data, 'capitalHistory');

    int countNew(List<Map<String, dynamic>> items, Set<String> existingIds) =>
        items
            .where((m) => !existingIds.contains((m['id'] ?? '').toString()))
            .length;

    final newCustomers = countNew(customers, existingCustomerIds);
    final newLoans = countNew(loans, existingLoanIds);
    final newPayments = countNew(payments, existingPaymentIds);
    final newCapitalEntries = countNew(capitalEntries, existingCapitalIds);

    return BackupPreview(
      newCustomers: newCustomers,
      newLoans: newLoans,
      newPayments: newPayments,
      newCapitalEntries: newCapitalEntries,
      duplicateCustomers: customers.length - newCustomers,
      duplicateLoans: loans.length - newLoans,
      duplicatePayments: payments.length - newPayments,
      duplicateCapitalEntries: capitalEntries.length - newCapitalEntries,
    );
  }

  /// Restaura clientes, préstamos, pagos y capital desde un respaldo JSON.
  /// Los registros cuyo id ya existe localmente se omiten (no se
  /// duplican). El orden de escritura (clientes → préstamos → pagos)
  /// respeta las referencias entre ellos.
  Future<void> importBackup(Map<String, dynamic> data) async {
    await _database.importLegacyBackup(data);
    await fetchAll();
  }

  Future<void> resetAllData() async {
    await _database.clearAllUserData();
    await clearData(eraseLocal: true);
  }

  Future<void> clearData({bool eraseLocal = false}) async {
    _customers = [];
    _allLoans = [];
    _allPayments = [];
    _capitalHistory = [];
    _paginatedPayments = [];
    _paginatedCustomers = [];
    _initialCapital = 0.0;
    _businessName = null;
    _businessLogoPath = null;
    _isLoading = false;
    _currentOffset = 0;
    _currentCustomerOffset = 0;
    _hasMorePayments = true;
    _hasMoreCustomers = true;
    if (eraseLocal) await _cache.clearAll();
    _recalculateMetrics();
    notifyListeners();
  }

  void _recalculateMetrics() {
    double totalReceivable = 0.0;
    double activeCapital = 0.0;
    double totalCollected = 0.0;
    double recoveredCapital = 0.0;
    double accruedInterest = 0.0;
    double paidInterest = 0.0;
    double outstandingCapital = 0.0;

    final byLoan = _paymentsByLoan();
    for (final loan in _allLoans) {
      final state = LoanCalculator.compute(loan, byLoan[loan.id] ?? const []);
      totalReceivable += state.totalDebt;
      // "Capital comprometido" en términos de caja: todo lo prestado (el neto
      // recuperado ya vuelve por totalCollected en moneyInHand).
      activeCapital += loan.initialAmount;
      // Capital realmente amortizado (los pagos que fueron a interés no cuentan).
      recoveredCapital += state.capitalPaid;
      // Interés generado a la fecha (pagado + pendiente) = ganancia proyectada.
      accruedInterest += state.accruedInterest;
      paidInterest += state.interestPaid;
      outstandingCapital += state.outstandingCapital;
    }

    for (final payment in _allPayments) {
      totalCollected += payment.amount;
    }

    _totalReceivable = totalReceivable;
    _activeCapital = outstandingCapital;
    _totalCollected = totalCollected;
    _recoveredCapital = recoveredCapital;
    _projectedProfit = accruedInterest;
    // Ganancia realizada = interés efectivamente cobrado = total cobrado menos
    // el capital recuperado.
    _realizedProfit = paidInterest;
    _moneyInHand = _initialCapital - activeCapital + totalCollected;
  }
}
