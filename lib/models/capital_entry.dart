class CapitalEntry {
  final String? id;
  final double amount;
  final String? note;
  final DateTime createdAt;

  CapitalEntry({
    this.id,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap({bool snakeCase = true}) {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'note': note,
      snakeCase ? 'created_at' : 'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CapitalEntry.fromMap(Map<String, dynamic> map) {
    return CapitalEntry(
      id: map['id'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      note: map['note'],
      createdAt: DateTime.parse(map['created_at'] ??
          map['createdAt'] ??
          DateTime.now().toIso8601String()),
    );
  }
}
