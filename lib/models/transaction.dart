enum IncrementType {
  fixed, // Fixed dollar amount per period
  percentage, // Percentage of the initial amount per period
}

enum IncrementPeriod {
  daily, // Cada día
  weekly, // Cada semana
  biweekly, // Cada quincena
  monthly, // Cada mes
}

extension IncrementPeriodX on IncrementPeriod {
  DateTime dateAt(DateTime start, int index) {
    if (this != IncrementPeriod.monthly) {
      return start.add(Duration(days: lengthInDays * index));
    }
    final lastDay = DateTime(start.year, start.month + index + 1, 0).day;
    return DateTime(
        start.year,
        start.month + index,
        start.day > lastDay ? lastDay : start.day,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
        start.microsecond);
  }

  int get lengthInDays {
    switch (this) {
      case IncrementPeriod.daily:
        return 1;
      case IncrementPeriod.weekly:
        return 7;
      case IncrementPeriod.biweekly:
        return 15;
      case IncrementPeriod.monthly:
        return 30;
    }
  }

  String get label {
    switch (this) {
      case IncrementPeriod.daily:
        return 'Día';
      case IncrementPeriod.weekly:
        return 'Semana';
      case IncrementPeriod.biweekly:
        return 'Quincena';
      case IncrementPeriod.monthly:
        return 'Mes';
    }
  }
}

class LoanTransaction {
  final dynamic id;
  final dynamic customerId;
  final String title;
  final double initialAmount;
  final DateTime startDate;
  final IncrementType incrementType;
  final double incrementValue;
  final IncrementPeriod incrementPeriod;
  final double amountPaid;

  /// Política de interés vencido para ESTE préstamo (no es un ajuste global):
  ///  - true (por defecto, Opción B): al llegar cada vencimiento se genera un
  ///    nuevo interés aunque el anterior siga pendiente (se acumulan). La base
  ///    del cálculo sigue siendo SIEMPRE el capital pendiente, nunca el total.
  ///  - false (Opción A): no se genera interés nuevo mientras haya interés
  ///    vencido sin pagar.
  final bool accumulateOverdueInterest;

  LoanTransaction({
    this.id,
    required this.customerId,
    required this.title,
    required this.initialAmount,
    required this.startDate,
    required this.incrementType,
    required this.incrementValue,
    this.incrementPeriod = IncrementPeriod.daily,
    this.amountPaid = 0.0,
    this.accumulateOverdueInterest = true,
  });

  Map<String, dynamic> toMap({bool snakeCase = false}) {
    return {
      if (id != null) 'id': id,
      snakeCase ? 'customer_id' : 'customerId': customerId,
      'title': title,
      snakeCase ? 'initial_amount' : 'initialAmount': initialAmount,
      snakeCase ? 'start_date' : 'startDate': startDate.toIso8601String(),
      snakeCase ? 'increment_type' : 'incrementType': incrementType.index,
      snakeCase ? 'increment_value' : 'incrementValue': incrementValue,
      snakeCase ? 'increment_period' : 'incrementPeriod': incrementPeriod.index,
      snakeCase ? 'amount_paid' : 'amountPaid': amountPaid,
      snakeCase ? 'accumulate_overdue_interest' : 'accumulateOverdueInterest':
          accumulateOverdueInterest,
    };
  }

  /// Interpreta valores booleanos que pueden venir como bool, número (0/1) o
  /// texto según la fuente (la base local, espejo local, backups antiguos).
  static bool _parseBool(dynamic value, {bool fallback = true}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      return v == 'true' || v == '1';
    }
    return fallback;
  }

  factory LoanTransaction.fromMap(Map<String, dynamic> map) {
    return LoanTransaction(
      id: map['id'],
      customerId: map['customerId'] ?? map['customer_id'],
      title: map['title'],
      initialAmount:
          (map['initialAmount'] ?? map['initial_amount'] ?? 0.0).toDouble(),
      startDate: DateTime.parse(map['startDate'] ?? map['start_date']),
      incrementType: IncrementType
          .values[map['incrementType'] ?? map['increment_type'] ?? 0],
      incrementValue:
          (map['incrementValue'] ?? map['increment_value'] ?? 0.0).toDouble(),
      incrementPeriod: IncrementPeriod
          .values[map['incrementPeriod'] ?? map['increment_period'] ?? 0],
      amountPaid: (map['amountPaid'] ?? map['amount_paid'] ?? 0.0).toDouble(),
      // Préstamos antiguos (sin la columna) adoptan la Opción B por defecto.
      accumulateOverdueInterest: _parseBool(
          map['accumulateOverdueInterest'] ??
              map['accumulate_overdue_interest'],
          fallback: true),
    );
  }
}
