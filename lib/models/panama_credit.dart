import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'credit_engine.dart';

/// Evidence supplied by the operator, never an assertion of regulatory approval.
class PanamaContract {
  static const version = 'PA-consumo-saldo-2026.1';
  static const fields = {
    'lenderName': 'Nombre o razón social del prestamista',
    'lenderId': 'RUC o identificación del prestamista',
    'lenderAddress': 'Domicilio del prestamista',
    'authorization': 'Autorización o fundamento del régimen aplicable',
    'representative': 'Representante que firma por el prestamista',
    'borrowerId': 'Cédula o pasaporte del deudor',
    'borrowerAddress': 'Domicilio del deudor',
    'place': 'Lugar de celebración',
    'signedDocument': 'Referencia del contrato firmado por ambas partes',
    'copyDelivery': 'Constancia de entrega de copia al deudor',
  };

  static void validate(Map<String, dynamic> data, CreditTerms terms) {
    terms.validateForContract();
    for (final entry in fields.entries) {
      if (data[entry.key] is! String ||
          (data[entry.key] as String).trim().length < 3) {
        throw ArgumentError('Completa: ${entry.value}.');
      }
    }
    if (!['financiera', 'particular', 'banco'].contains(data['lenderType']) ||
        data['accepted'] != true ||
        data['identityVerified'] != true) {
      throw ArgumentError(
          'Identifica el régimen y acredita identidad, firmas y entrega de copia.');
    }
    if (terms.monthlyInsurance > 0 &&
        (data['insuranceEvidence'] is! String ||
            (data['insuranceEvidence'] as String).trim().length < 5)) {
      throw ArgumentError(
          'Identifica aseguradora, póliza y condiciones de devolución de primas.');
    }
    if (data['product'] != 'personalMonthlyVoluntary') {
      throw ArgumentError(
          'Este contrato admite crédito personal mensual de pago voluntario.');
    }
  }

  static String digest(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();

  static Map<String, dynamic> snapshot(Map<String, dynamic> data,
      CreditTerms terms, String borrowerName, String purpose, DateTime date) {
    validate(data, terms);
    final body = <String, dynamic>{
      ...data,
      'templateVersion': version,
      'borrowerName': borrowerName,
      'purpose': purpose,
      'date': date.toIso8601String(),
      'currency': 'USD',
      'terms': terms.toMap(),
      'effectiveAnnualRate': CreditEngine.effectiveAnnualRate(terms),
      'totalAnnualCost':
          CreditEngine.effectiveAnnualRate(terms, includeThirdParties: true),
      'netDisbursementCents': (terms.principal * 100).round(),
      'repayment':
          'Cuotas mensuales de pago voluntario; sin descuento de salario.',
      'fees':
          'Comisión propia cobrada en primera cuota. Sin retenciones al desembolso ni refinanciamientos.',
      'insurance':
          'Prima mensual destinada íntegramente a la aseguradora; devoluciones conforme a póliza y evidencia, sin cobrar primas de períodos futuros.',
      'prepayment':
          'Cancelación total sin penalización: capital pendiente e interés devengado. Prorrateo diario dentro de cada período mensual; sin capitalización. Se descuentan intereses y FECI futuros. Los adelantos de cuotas no sustituyen una cancelación total.',
      'latePolicy':
          'Recargo único sobre capital impago al vencer cada cuota, sin interés sobre interés.',
    };
    return {...body, 'sha256': digest(body)};
  }

  static void validateSnapshot(
      Map<String, dynamic> snapshot, CreditTerms terms) {
    validate(snapshot, terms);
    final body = {...snapshot}..remove('sha256');
    if (snapshot['templateVersion'] != version ||
        snapshot['sha256'] != digest(body) ||
        jsonEncode(snapshot['terms']) != jsonEncode(terms.toMap()) ||
        snapshot['effectiveAnnualRate'] !=
            CreditEngine.effectiveAnnualRate(terms) ||
        snapshot['totalAnnualCost'] !=
            CreditEngine.effectiveAnnualRate(terms,
                includeThirdParties: true)) {
      throw ArgumentError('Documento contractual alterado o incompatible.');
    }
  }
}

class CreditSettlement {
  static DateTime day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
  static const components = [
    'principal',
    'interest',
    'insurance',
    'fee',
    'feci'
  ];

  /// Reconciles a full payoff against actual receipts. Historical schedules
  /// remain immutable. Future insurance is removed; any additional insurer
  /// refund requires a documented adjustment outside this calculation.
  static Map<String, dynamic> quote(
      {required CreditTerms terms,
      required List<Map<String, dynamic>> schedule,
      required List<Map<String, dynamic>> payments,
      required DateTime start,
      required DateTime at}) {
    final date = day(at);
    if (date.isBefore(day(start)) || schedule.isEmpty) {
      throw ArgumentError('Fecha de liquidación anterior al desembolso.');
    }
    final actual = payments
        .where((p) =>
            p['voided'] != true &&
            !DateTime.parse(p['date'] as String).isAfter(at))
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    if (actual.any((p) => p['kind'] == 'settlement')) {
      throw StateError('El crédito ya tiene una cancelación vigente.');
    }
    final balances = CreditEngine.balances(
        schedule, actual, (terms.lateFee * 100).round(), at);
    final initial = (terms.principal * 100).round();
    // Principal reductions follow the originally disclosed allocation order.
    final movements = <(DateTime, int)>[];
    var principalPaid = 0;
    for (var i = 0; i < actual.length; i++) {
      final rows = CreditEngine.balances(
          schedule,
          actual.take(i + 1).toList(),
          (terms.lateFee * 100).round(),
          DateTime.parse(actual[i]['date'] as String));
      final paid =
          rows.fold<int>(0, (s, r) => s + (r['principalPaidCents'] as int));
      movements.add((
        day(DateTime.parse(actual[i]['date'] as String)),
        paid - principalPaid
      ));
      principalPaid = paid;
    }
    final totals = {for (final c in components) '${c}Cents': 0, 'lateCents': 0};
    var removedInterest = 0, removedFeci = 0, removedInsurance = 0;
    final closing = <Map<String, dynamic>>[];
    var previous = day(start);
    for (var index = 0; index < schedule.length; index++) {
      final source = schedule[index];
      final due = day(DateTime.parse(source['due'] as String));
      final end = date.isBefore(due) ? date : due;
      final base =
          index == 0 ? initial : schedule[index - 1]['balanceCents'] as int;
      final length = due.difference(previous).inDays;
      var weightedDays = 0.0;
      if (end.isAfter(previous) && base > 0) {
        var cursor = previous;
        var capital = initial;
        for (final movement in movements) {
          if (!movement.$1.isAfter(previous)) capital -= movement.$2;
        }
        for (final movement in movements
            .where((m) => m.$1.isAfter(previous) && m.$1.isBefore(end))) {
          weightedDays += min(base, max(0, capital)) *
              movement.$1.difference(cursor).inDays /
              base;
          capital -= movement.$2;
          cursor = movement.$1;
        }
        weightedDays +=
            min(base, max(0, capital)) * end.difference(cursor).inDays / base;
      }
      final fraction =
          length <= 0 ? 0.0 : (weightedDays / length).clamp(0.0, 1.0);
      final interest = ((source['interestCents'] as int) * fraction).round();
      final feci = ((source['feciCents'] as int? ?? 0) * fraction).round();
      final insurance =
          date.isAfter(previous) ? source['insuranceCents'] as int : 0;
      removedInterest += (source['interestCents'] as int) - interest;
      removedFeci += (source['feciCents'] as int? ?? 0) - feci;
      removedInsurance += (source['insuranceCents'] as int) - insurance;
      final row = <String, dynamic>{
        ...source,
        'interestCents': interest,
        'insuranceCents': insurance,
        'feciCents': feci,
        'lateCents': balances[index]['lateCents'],
        'remainingCents': 0
      };
      var rowTotal = 0;
      for (final component in components) {
        final value = row['${component}Cents'] as int;
        row['${component}PaidCents'] = value;
        totals['${component}Cents'] = totals['${component}Cents']! + value;
        rowTotal += value;
      }
      row['totalCents'] = rowTotal;
      row['paidCents'] = rowTotal;
      row['latePaidCents'] = row['lateCents'];
      totals['lateCents'] = totals['lateCents']! + (row['lateCents'] as int);
      closing.add(row);
      previous = due;
    }
    final paid = actual.fold<int>(0, (s, p) => s + (p['amountCents'] as int));
    final earned = totals.values.fold<int>(0, (s, v) => s + v);
    return {
      'version': 1,
      'date': at.toIso8601String(),
      'principalOutstandingCents': initial - principalPaid,
      ...totals,
      'receivedCents': paid,
      'earnedTotalCents': earned,
      'netCents': earned - paid,
      'interestWaivedCents': removedInterest,
      'feciWaivedCents': removedFeci,
      'insuranceWaivedCents': removedInsurance,
      'penaltyCents': 0,
      'closingRows': closing,
      'basisHash': PanamaContract.digest(
          {'terms': terms.toMap(), 'schedule': schedule, 'payments': actual}),
    };
  }
}
