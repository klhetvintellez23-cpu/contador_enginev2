class Payment {
  final dynamic id;
  final dynamic loanId;
  final double amount;
  final DateTime date;
  final String? customerName; // Handy for history views without complex joins

  Payment({
    this.id,
    required this.loanId,
    required this.amount,
    required this.date,
    this.customerName,
  });

  Map<String, dynamic> toMap({bool snakeCase = false}) {
    return {
      if (id != null) 'id': id,
      snakeCase ? 'loan_id' : 'loanId': loanId,
      'amount': amount,
      'date': date.toIso8601String(),
      snakeCase ? 'customer_name' : 'customerName': customerName,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      loanId: map['loanId'] ?? map['loan_id'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: DateTime.parse(map['date']),
      customerName: map['customerName'] ?? map['customer_name'],
    );
  }
}
