import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/credit_engine.dart';
import '../models/credit_account.dart';
import '../models/panama_credit.dart';
import 'local_database_service.dart';

enum ApplicationStatus {
  draft,
  submitted,
  compliance,
  management,
  approved,
  rejected,
  returned
}

extension ApplicationStatusLabel on ApplicationStatus {
  String get label => switch (this) {
        ApplicationStatus.draft => 'Borrador',
        ApplicationStatus.submitted => 'En análisis',
        ApplicationStatus.compliance => 'En cumplimiento',
        ApplicationStatus.management => 'En gerencia',
        ApplicationStatus.approved => 'Aprobada',
        ApplicationStatus.rejected => 'Rechazada',
        ApplicationStatus.returned => 'Devuelta',
      };
}

class CreditService {
  final LocalDatabaseService db;
  CreditService({LocalDatabaseService? database})
      : db = database ?? LocalDatabaseService();
  List<Map<String, dynamic>> get applications =>
      LocalDatabaseService.rowsOf(db.readWorkflow(), 'applications');
  List<Map<String, dynamic>> payments(String id) =>
      LocalDatabaseService.rowsOf(db.readWorkflow(), 'credit_payments')
          .where((p) => p['applicationId'] == id)
          .toList();
  Map<String, dynamic>? account(String applicationId) =>
      LocalDatabaseService.rowsOf(db.readWorkflow(), 'credit_accounts')
          .where((a) => a['applicationId'] == applicationId)
          .firstOrNull;
  CreditLifecycle lifecycle(Map<String, dynamic> app) {
    final record = account(app['id'] as String);
    if (record != null) {
      return record['status'] == 'active'
          ? CreditLifecycle.active
          : CreditLifecycle.formalized;
    }
    return app['creditLifecycle'] == 'awaitingFormalization'
        ? CreditLifecycle.awaitingFormalization
        : CreditLifecycle.legacy;
  }

  Map<String, int> get portfolioSummary {
    var balanceCents = 0, interestPaidCents = 0, overdue = 0, settled = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final app in applications.where((a) =>
        a['status'] == 'approved' && lifecycle(a) == CreditLifecycle.active)) {
      final rows = balance(app);
      var loanBalance = 0;
      var late = false;
      for (final row in rows) {
        final remaining = row['remainingCents'] as int;
        loanBalance += remaining;
        interestPaidCents += row['interestPaidCents'] as int;
        if (remaining > 0 &&
            DateTime.parse(row['due'] as String).isBefore(today)) {
          late = true;
        }
      }
      balanceCents += loanBalance;
      if (late) overdue++;
      if (loanBalance == 0) settled++;
    }
    return {
      'balanceCents': balanceCents,
      'interestPaidCents': interestPaidCents,
      'overdue': overdue,
      'settled': settled
    };
  }

  Map<String, dynamic> _find(Map<String, dynamic> s, String id) {
    final apps = LocalDatabaseService.rowsOf(s, 'applications');
    final index = apps.indexWhere((a) => a['id'] == id);
    if (index < 0) throw StateError('Solicitud inexistente.');
    s['applications'] = apps;
    return apps[index];
  }

  Future<String> create(
          String purpose, CreditTerms terms, FinancialProfile profile) =>
      db.transaction('solicitud:crear', (s) {
        terms.validate();
        if (terms.policyVersion != 2) {
          throw ArgumentError(
              'Usa las condiciones vigentes para nuevos créditos.');
        }
        profile.validate();
        if (purpose.trim().length < 5) {
          throw ArgumentError(
              'Explica el destino del crédito (mínimo 5 caracteres).');
        }
        final id = const Uuid().v4();
        s['applications'] = [
          ...LocalDatabaseService.rowsOf(s, 'applications'),
          {
            'id': id,
            'ownerId': db.currentUser!.id,
            'applicant': db.currentUser!.name,
            'purpose': purpose.trim(),
            'terms': terms.toMap(),
            'profile': profile.toMap(),
            'status': ApplicationStatus.draft.name,
            'createdAt': DateTime.now().toIso8601String(),
            'decisions': <dynamic>[]
          }
        ];
        return id;
      }, roles: {UserRole.client});
  Future<void> revise(String id, String purpose, CreditTerms terms,
          FinancialProfile profile) =>
      db.transaction('solicitud:corregir:$id', (s) {
        final a = _find(s, id);
        if (a['ownerId'] != db.currentUser!.id ||
            !['draft', 'returned'].contains(a['status'])) {
          throw StateError(
              'Solo puedes corregir tus borradores o solicitudes devueltas.');
        }
        terms.validate();
        profile.validate();
        if (purpose.trim().length < 5) {
          throw ArgumentError('Explica el destino del crédito.');
        }
        a.addAll({
          'purpose': purpose.trim(),
          'terms': terms.toMap(),
          'profile': profile.toMap(),
          'status': 'draft'
        });
        a.remove('evaluation');
      }, roles: {UserRole.client});
  Future<void> submit(String id) => db.transaction('solicitud:enviar:$id', (s) {
        final a = _find(s, id);
        if (a['ownerId'] != db.currentUser!.id || a['status'] != 'draft') {
          throw StateError('No puedes enviar esta solicitud.');
        }
        CreditTerms.fromMap(Map<String, dynamic>.from(a['terms'] as Map))
            .validateForContract();
        a['status'] = 'submitted';
      }, roles: {UserRole.client});
  Future<void> evaluate(String id) =>
      db.transaction('solicitud:evaluar:$id', (s) {
        final a = _find(s, id);
        if (a['ownerId'] == db.currentUser!.id || a['status'] != 'submitted') {
          throw StateError('La solicitud no está en análisis.');
        }
        final terms =
            CreditTerms.fromMap(Map<String, dynamic>.from(a['terms'] as Map));
        final plan = CreditEngine.schedule(terms, DateTime.now());
        final maxPayment = plan.map((r) => r.totalCents).reduce(max) / 100;
        final rules = Map<String, dynamic>.from(
            (s['scoring_rules'] as Map?) ?? {'version': 1, 'maxDti': 0.4});
        a['evaluation'] = ScoringRules(
                version: rules['version'] as int,
                maxDti: (rules['maxDti'] as num).toDouble())
            .evaluate(
                FinancialProfile.fromMap(
                    Map<String, dynamic>.from(a['profile'] as Map)),
                maxPayment);
        (a['evaluation'] as Map)['evaluatedBy'] = db.currentUser!.id;
      }, roles: {UserRole.analyst});
  Future<void> decide(String id, String decision, String reason) =>
      db.transaction('solicitud:$decision:$id', (s) {
        if (!['advance', 'reject', 'return'].contains(decision) ||
            reason.trim().length < 5) {
          throw ArgumentError(
              'Selecciona una decisión y explica el motivo (mínimo 5 caracteres).');
        }
        final a = _find(s, id);
        final user = db.currentUser!;
        final expected = {
          UserRole.analyst: 'submitted',
          UserRole.compliance: 'compliance',
          UserRole.manager: 'management'
        }[user.role];
        if (a['ownerId'] == user.id ||
            expected == null ||
            a['status'] != expected) {
          throw StateError('No puedes decidir en esta etapa.');
        }
        if (decision == 'advance' &&
            (a['evaluation'] as Map?)?['eligible'] != true) {
          throw StateError('La evaluación debe ser favorable para avanzar.');
        }
        final events = (a['decisions'] as List?) ?? [];
        final next = decision == 'reject'
            ? 'rejected'
            : decision == 'return'
                ? 'returned'
                : user.role == UserRole.analyst
                    ? 'compliance'
                    : user.role == UserRole.compliance
                        ? 'management'
                        : 'approved';
        events.add({
          'actor': user.id,
          'role': user.role.name,
          'from': a['status'],
          'to': next,
          'reason': reason.trim(),
          'date': DateTime.now().toIso8601String()
        });
        a['decisions'] = events;
        a['status'] = next;
        if (next == 'approved') {
          final start = DateTime.now();
          final terms =
              CreditTerms.fromMap(Map<String, dynamic>.from(a['terms'] as Map));
          a['approvedAt'] = start.toIso8601String();
          a['creditLifecycle'] = 'awaitingFormalization';
          a['quotedSchedule'] = CreditEngine.schedule(terms, start)
              .map((r) => r.toMap())
              .toList();
        }
      }, roles: {UserRole.analyst, UserRole.compliance, UserRole.manager});
  List<Map<String, dynamic>> balance(Map<String, dynamic> a, {DateTime? asOf}) {
    final record = account(a['id'] as String);
    if (record?['status'] == 'active') {
      return PortfolioLedger.accountBalance(db.readWorkflow(), record!,
          asOf: asOf);
    }
    final schedule = record?['status'] == 'active'
        ? LocalDatabaseService.rowsOf(record!, 'schedule')
        : lifecycle(a) == CreditLifecycle.legacy
            ? LocalDatabaseService.rowsOf(a, 'schedule')
            : <Map<String, dynamic>>[];
    return CreditEngine.balances(
        schedule,
        payments(a['id'] as String),
        (((a['terms'] as Map)['lateFee'] as num) * 100).round(),
        asOf ?? DateTime.now());
  }

  Future<void> formalize(
          String id, String customerId, String acceptanceReference,
          {Map<String, dynamic>? contract}) =>
      db.transaction('credito:formalizar:$id', (s) {
        final app = _find(s, id);
        if (app['status'] != 'approved' ||
            app['creditLifecycle'] != 'awaitingFormalization') {
          throw StateError(
              'Esta solicitud no está pendiente de formalización.');
        }
        if (acceptanceReference.trim().length < 5) {
          throw ArgumentError('Registra la referencia del acuerdo aceptado.');
        }
        if (!LocalDatabaseService.rowsOf(s, 'customers')
            .any((c) => c['id'].toString() == customerId)) {
          throw ArgumentError(
              'Selecciona un cliente existente y verifica su identidad.');
        }
        final records = LocalDatabaseService.rowsOf(s, 'credit_accounts');
        if (records.any((c) => c['applicationId'] == id)) {
          throw StateError('Esta solicitud ya tiene un crédito vinculado.');
        }
        final terms =
            CreditTerms.fromMap(Map<String, dynamic>.from(app['terms'] as Map));
        if (contract == null) {
          throw ArgumentError(
              'Completa el documento contractual y su evidencia.');
        }
        final customer = LocalDatabaseService.rowsOf(s, 'customers')
            .firstWhere((c) => c['id'].toString() == customerId);
        final document = PanamaContract.snapshot(
            contract,
            terms,
            customer['name'] as String,
            app['purpose'] as String,
            DateTime.now());
        records.add({
          'id': const Uuid().v4(),
          'applicationId': id,
          'ownerId': app['ownerId'],
          'customerId': customerId,
          'status': 'formalized',
          'terms': Map<String, dynamic>.from(app['terms'] as Map),
          'termsVersion': 2,
          'contract': document,
          'acceptanceReference': acceptanceReference.trim(),
          'formalizedAt': DateTime.now().toIso8601String(),
          'formalizedBy': db.currentUser!.id,
          'legacy': false,
          'schedule': <dynamic>[],
          'cashPrincipalCents': 0,
          'cashPaymentBaselineCents': 0,
        });
        s['credit_accounts'] = records;
      });

  Future<void> disburse(String id, DateTime effectiveDate, String reference) =>
      db.transaction('credito:desembolsar:$id', (s) {
        final app = _find(s, id);
        final records = LocalDatabaseService.rowsOf(s, 'credit_accounts');
        final record =
            records.where((r) => r['applicationId'] == id).firstOrNull;
        if (record == null || app['status'] != 'approved') {
          throw StateError('Formaliza primero el crédito.');
        }
        final date = DateTime(
            effectiveDate.year, effectiveDate.month, effectiveDate.day);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final formalized = DateTime.parse(record['formalizedAt'] as String);
        final firstDay =
            DateTime(formalized.year, formalized.month, formalized.day);
        if (reference.trim().length < 3 ||
            date.isBefore(firstDay) ||
            date.isAfter(today)) {
          throw ArgumentError(
              'Revisa la referencia y la fecha del desembolso.');
        }
        if (record['status'] == 'active') {
          if (record['disbursementReference'] == reference.trim() &&
              record['disbursedAt'] == date.toIso8601String()) {
            return;
          }
          throw StateError('El crédito ya fue desembolsado.');
        }
        if (records.any((r) =>
            r['status'] == 'active' &&
            r['disbursementReference'] == reference.trim())) {
          throw StateError('La referencia de desembolso ya está registrada.');
        }
        final terms = CreditTerms.fromMap(
            Map<String, dynamic>.from(record['terms'] as Map));
        if (record['termsVersion'] == 2) {
          PanamaContract.validateSnapshot(
              Map<String, dynamic>.from(record['contract'] as Map), terms);
        }
        if (terms.principal > PortfolioLedger.availableCash(s) + .001) {
          throw StateError(
              'Capital insuficiente para registrar este desembolso.');
        }
        record.addAll({
          'status': 'active',
          'disbursedAt': date.toIso8601String(),
          'disbursementReference': reference.trim(),
          'disbursedBy': db.currentUser!.id,
          'activatedAt': now.toIso8601String(),
          'cashPrincipalCents': (terms.principal * 100).round(),
          'schedule':
              CreditEngine.schedule(terms, date).map((r) => r.toMap()).toList(),
        });
        s['credit_accounts'] = records;
      });

  /// Explicit opening reconciliation preserves the old plan and all payments.
  Future<void> reconcileLegacy(
          String id, String customerId, DateTime disbursedAt, String evidence,
          {required bool cashAlreadyIncluded}) =>
      db.transaction('credito:conciliar:$id', (s) {
        final app = _find(s, id);
        final records = LocalDatabaseService.rowsOf(s, 'credit_accounts');
        if (app['status'] != 'approved' ||
            app['creditLifecycle'] != null ||
            records.any((r) => r['applicationId'] == id)) {
          throw StateError(
              'Solo puedes conciliar un crédito anterior una vez.');
        }
        if (evidence.trim().length < 5 ||
            disbursedAt.isAfter(DateTime.now()) ||
            !LocalDatabaseService.rowsOf(s, 'customers')
                .any((c) => c['id'].toString() == customerId)) {
          throw ArgumentError(
              'Verifica cliente, fecha real y evidencia del desembolso anterior.');
        }
        final terms =
            CreditTerms.fromMap(Map<String, dynamic>.from(app['terms'] as Map));
        final schedule = LocalDatabaseService.rowsOf(app, 'schedule');
        if (schedule.isEmpty) {
          throw StateError('Falta el plan anterior; requiere revisión manual.');
        }
        CreditEngine.balances(
            schedule,
            LocalDatabaseService.rowsOf(s, 'credit_payments')
                .where((p) => p['applicationId'] == id)
                .toList(),
            (terms.lateFee * 100).round(),
            DateTime.now());
        records.add({
          'id': const Uuid().v4(),
          'applicationId': id,
          'ownerId': app['ownerId'],
          'customerId': customerId,
          'status': 'active',
          'terms': terms.toMap(),
          'termsVersion': 1,
          'legacy': true,
          'schedule': schedule,
          'acceptanceReference': evidence.trim(),
          'disbursementReference': 'conciliacion:$id',
          'disbursedAt': disbursedAt.toIso8601String(),
          'formalizedAt': DateTime.now().toIso8601String(),
          'formalizedBy': db.currentUser!.id,
          'activatedAt': DateTime.now().toIso8601String(),
          'disbursedBy': db.currentUser!.id,
          'cashAlreadyIncluded': cashAlreadyIncluded,
          'cashPrincipalCents':
              cashAlreadyIncluded ? 0 : (terms.principal * 100).round(),
          'cashPaymentBaselineCents':
              cashAlreadyIncluded ? PortfolioLedger.activePayments(s, id) : 0,
        });
        s['credit_accounts'] = records;
      });
  Future<void> pay(String id, double amount, String reference) =>
      db.transaction('credito:pago:$id', (s) {
        LocalDatabaseService.positive(amount, 'Pago');
        if (reference.trim().length < 3) {
          throw ArgumentError('Indica una referencia del pago.');
        }
        final a = _find(s, id);
        final activeAccount = LocalDatabaseService.rowsOf(s, 'credit_accounts')
            .where((r) => r['applicationId'] == id && r['status'] == 'active')
            .firstOrNull;
        if (a['status'] != 'approved' || activeAccount == null) {
          throw StateError(
              'Registra el desembolso o concilia el crédito antes de cobrar.');
        }
        final rows = LocalDatabaseService.rowsOf(s, 'credit_payments');
        if (activeAccount['settlement'] != null) {
          throw StateError('El crédito ya está cancelado.');
        }
        if (rows.any((p) =>
            p['applicationId'] == id &&
            p['reference'] == reference.trim() &&
            p['voided'] != true)) {
          throw StateError('Esta referencia de pago ya existe.');
        }
        final cents = (amount * 100).round();
        if (cents <= 0 || (amount * 100 - cents).abs() > 0.0001) {
          throw ArgumentError('Usa como máximo dos decimales.');
        }
        final payoff = _settlementQuote(s, activeAccount, DateTime.now());
        if (cents >= (payoff['netCents'] as int)) {
          throw ArgumentError(
              'Usa Cancelar préstamo para liquidar sin intereses futuros.');
        }
        final payment = {
          'id': const Uuid().v4(),
          'applicationId': id,
          'accountId': activeAccount['id'],
          'amountCents': cents,
          'reference': reference.trim(),
          'date': DateTime.now().toIso8601String(),
          'actor': db.currentUser!.id,
          'voided': false
        };
        final all = [...rows, payment];
        CreditEngine.balances(
            LocalDatabaseService.rowsOf(activeAccount, 'schedule'),
            all.where((p) => p['applicationId'] == id).toList(),
            (((a['terms'] as Map)['lateFee'] as num) * 100).round(),
            DateTime.now());
        s['credit_payments'] = all;
      }, roles: {UserRole.manager});
  Future<void> voidPayment(String id, String reason) =>
      db.transaction('credito:anular_pago:$id', (s) {
        if (reason.trim().length < 5) {
          throw ArgumentError('Explica el motivo de la anulación.');
        }
        final rows = LocalDatabaseService.rowsOf(s, 'credit_payments');
        final payment = rows.firstWhere((p) => p['id'] == id);
        if (payment['voided'] == true) {
          throw StateError('El pago ya está anulado.');
        }
        final accounts = LocalDatabaseService.rowsOf(s, 'credit_accounts');
        final record = accounts
            .where((a) => a['applicationId'] == payment['applicationId'])
            .firstOrNull;
        if (record?['settlement'] != null) {
          if ((record!['settlement'] as Map)['paymentId'] != id) {
            throw StateError(
                'Anula primero la cancelación para corregir un pago anterior.');
          }
          record.remove('settlement');
          s['credit_accounts'] = accounts;
        }
        payment['voided'] = true;
        payment['voidReason'] = reason.trim();
        payment['voidedBy'] = db.currentUser!.id;
        s['credit_payments'] = rows;
      }, roles: {UserRole.manager});

  Map<String, dynamic> _settlementQuote(Map<String, dynamic> state,
          Map<String, dynamic> record, DateTime at) =>
      CreditSettlement.quote(
          terms: CreditTerms.fromMap(
              Map<String, dynamic>.from(record['terms'] as Map)),
          schedule: LocalDatabaseService.rowsOf(record, 'schedule'),
          payments: LocalDatabaseService.rowsOf(state, 'credit_payments')
              .where((p) => p['applicationId'] == record['applicationId'])
              .toList(),
          start: DateTime.parse(record['disbursedAt'] as String),
          at: at);

  Map<String, dynamic> settlementQuote(String id) {
    final record = account(id);
    if (record == null ||
        record['status'] != 'active' ||
        record['settlement'] != null) {
      throw StateError('Se requiere un crédito activo sin cancelar.');
    }
    return _settlementQuote(db.readWorkflow(), record, DateTime.now());
  }

  Map<String, int> paymentBreakdown(Map<String, dynamic> payment) {
    final record = account(payment['applicationId'] as String);
    if (record == null || payment['voided'] == true) return {};
    final ordered = payments(payment['applicationId'] as String)
        .where((p) => p['voided'] != true)
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    final index = ordered.indexWhere((p) => p['id'] == payment['id']);
    if (index < 0) return {};
    final at = DateTime.parse(payment['date'] as String);
    final beforeRecord = {...record}..remove('settlement');
    final before = PortfolioLedger.accountBalance(
        {'credit_payments': ordered.take(index).toList()}, beforeRecord,
        asOf: at);
    final after = PortfolioLedger.accountBalance({
      'credit_payments': ordered.take(index + 1).toList()
    }, payment['kind'] == 'settlement' ? record : beforeRecord, asOf: at);
    int sum(List<Map<String, dynamic>> rows, String key) =>
        rows.fold<int>(0, (s, r) => s + (r[key] as int? ?? 0));
    return {
      for (final c in [...CreditSettlement.components, 'late'])
        '${c}Cents': sum(after, '${c}PaidCents') - sum(before, '${c}PaidCents'),
      'balanceCents': sum(after, 'remainingCents'),
      'principalBalanceCents':
          sum(after, 'principalCents') - sum(after, 'principalPaidCents'),
    };
  }

  Future<void> settle(
          String id, Map<String, dynamic> acceptedQuote, String reference) =>
      db.transaction('credito:cancelar:$id', (s) {
        if (reference.trim().length < 3) {
          throw ArgumentError('Indica referencia del cobro o devolución.');
        }
        final accounts = LocalDatabaseService.rowsOf(s, 'credit_accounts');
        final record = accounts.firstWhere((a) => a['applicationId'] == id);
        if (record['status'] != 'active' || record['settlement'] != null) {
          throw StateError('El crédito no admite otra cancelación.');
        }
        final date = DateTime.parse(acceptedQuote['date'] as String);
        final now = DateTime.now();
        if (date.isAfter(now) ||
            CreditSettlement.day(date) != CreditSettlement.day(now)) {
          throw StateError(
              'Actualiza la liquidación; solo es válida durante el día de emisión.');
        }
        final quote = _settlementQuote(s, record, date);
        // Include receipts after the quote in the concurrency check.
        final latest = _settlementQuote(s, record, now);
        if (PanamaContract.digest(quote) !=
                PanamaContract.digest(acceptedQuote) ||
            quote['basisHash'] != latest['basisHash']) {
          throw StateError(
              'Los pagos cambiaron. Revisa una nueva liquidación.');
        }
        final rows = LocalDatabaseService.rowsOf(s, 'credit_payments');
        if (rows.any((p) =>
            p['applicationId'] == id &&
            p['voided'] != true &&
            p['reference'] == reference.trim())) {
          throw StateError('Esta referencia de pago ya existe.');
        }
        final net = quote['netCents'] as int;
        if (net < 0 &&
            -net > (PortfolioLedger.availableCash(s) * 100).round()) {
          throw StateError('Caja insuficiente para registrar la devolución.');
        }
        final paymentId = const Uuid().v4();
        rows.add({
          'id': paymentId,
          'applicationId': id,
          'accountId': record['id'],
          'kind': 'settlement',
          'direction': net < 0 ? 'refund' : 'receipt',
          'amountCents': net.abs(),
          'reference': reference.trim(),
          'date': date.toIso8601String(),
          'actor': db.currentUser!.id,
          'voided': false
        });
        record['settlement'] = {
          ...quote,
          'paymentId': paymentId,
          'actor': db.currentUser!.id
        };
        s['credit_payments'] = rows;
        s['credit_accounts'] = accounts;
      }, roles: {UserRole.manager});

  Future<String> createManaged(String customerId, String purpose,
          CreditTerms terms, FinancialProfile profile) =>
      db.transaction('credito:originar_directo', (s) {
        terms.validateForContract();
        profile.validate();
        if (purpose.trim().length < 5) {
          throw ArgumentError('Describe el destino del crédito.');
        }
        final customer = LocalDatabaseService.rowsOf(s, 'customers')
            .firstWhere((c) => c['id'].toString() == customerId);
        final now = DateTime.now();
        final plan = CreditEngine.schedule(terms, now);
        final rules =
            (s['scoring_rules'] as Map?) ?? {'version': 1, 'maxDti': 0.4};
        final evaluation = ScoringRules(
                version: rules['version'] as int,
                maxDti: (rules['maxDti'] as num).toDouble())
            .evaluate(profile, plan.map((r) => r.totalCents).reduce(max) / 100);
        if (evaluation['eligible'] != true) {
          throw StateError(
              'La capacidad de pago no cumple la política del negocio.');
        }
        final id = const Uuid().v4();
        s['applications'] = [
          ...LocalDatabaseService.rowsOf(s, 'applications'),
          {
            'id': id,
            'ownerId': db.currentUser!.id,
            'applicant': customer['name'],
            'purpose': purpose.trim(),
            'terms': terms.toMap(),
            'profile': profile.toMap(),
            'status': 'approved',
            'origin': 'managementDirect',
            'customerId': customerId,
            'evaluation': evaluation,
            'createdAt': now.toIso8601String(),
            'approvedAt': now.toIso8601String(),
            'creditLifecycle': 'awaitingFormalization',
            'quotedSchedule': plan.map((r) => r.toMap()).toList(),
            'decisions': [
              {
                'actor': db.currentUser!.id,
                'role': 'manager',
                'from': 'draft',
                'to': 'approved',
                'reason':
                    'Originación directa aprobada por gerencia; pendiente de contrato y desembolso.',
                'date': now.toIso8601String()
              }
            ]
          }
        ];
        return id;
      }, roles: {UserRole.manager});
  Future<void> configureRules(double maxDti) =>
      db.transaction('scoring:configurar', (s) {
        if (!maxDti.isFinite || maxDti <= 0 || maxDti > 1) {
          throw ArgumentError('DTI entre 1% y 100%.');
        }
        final previous = (s['scoring_rules'] as Map?)?['version'] as int? ?? 1;
        s['scoring_rules'] = {'version': previous + 1, 'maxDti': maxDti};
      }, roles: {UserRole.manager});
}
