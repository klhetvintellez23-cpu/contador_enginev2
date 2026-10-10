import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/credit_engine.dart';
import '../models/credit_account.dart';
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
          String id, String customerId, String acceptanceReference) =>
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
        records.add({
          'id': const Uuid().v4(),
          'applicationId': id,
          'ownerId': app['ownerId'],
          'customerId': customerId,
          'status': 'formalized',
          'terms': Map<String, dynamic>.from(app['terms'] as Map),
          'termsVersion': 1,
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
        payment['voided'] = true;
        payment['voidReason'] = reason.trim();
        payment['voidedBy'] = db.currentUser!.id;
        s['credit_payments'] = rows;
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
