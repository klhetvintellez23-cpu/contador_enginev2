class Customer {
  final dynamic id;
  final String name;
  final String? phone;
  final String? photoPath;
  final String? cedula;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.photoPath,
    this.cedula,
  });

  Map<String, dynamic> toMap({bool snakeCase = false}) {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'cedula': cedula,
      snakeCase ? 'photo_path' : 'photoPath': photoPath,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      cedula: map['cedula'],
      photoPath: map['photoPath'] ?? map['photo_path'],
    );
  }
}
