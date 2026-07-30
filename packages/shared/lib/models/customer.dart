/// Customer model — mirrors the backend Customer entity.
class Customer {
  final String id;
  final String? firebaseUid;
  final String phone;
  final String? name;
  final String? homeZoneId;
  final String? homeZoneName;
  final bool whatsappOptIn;
  final DateTime createdAt;

  const Customer({
    required this.id,
    this.firebaseUid,
    required this.phone,
    this.name,
    this.homeZoneId,
    this.homeZoneName,
    this.whatsappOptIn = false,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final zone = json['homeZone'] as Map<String, dynamic>?;
    return Customer(
      id: json['id'] as String,
      firebaseUid: json['firebaseUid'] as String?,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      homeZoneId: json['homeZoneId'] as String?,
      homeZoneName: zone?['name'] as String?,
      whatsappOptIn: json['whatsappOptIn'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }


  @override
  String toString() => 'Customer(id: $id, name: $name)';
}
