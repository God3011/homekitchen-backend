/// Kitchen model — mirrors the backend Kitchen entity.
class Kitchen {
  final String id;
  final String kitchenName;
  final String? cookName;
  final String phone;
  final String status; // 'pending_review' | 'verified' | 'suspended'
  final String? zoneId;
  final String? addressLine;
  final double? lat;
  final double? lng;
  final String? story;
  final String? signatureDish;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const Kitchen({
    required this.id,
    required this.kitchenName,
    this.cookName,
    required this.phone,
    required this.status,
    this.zoneId,
    this.addressLine,
    this.lat,
    this.lng,
    this.story,
    this.signatureDish,
    this.verifiedAt,
    required this.createdAt,
  });

  factory Kitchen.fromJson(Map<String, dynamic> json) {
    return Kitchen(
      id: json['id'] as String,
      kitchenName: json['kitchenName'] as String,
      cookName: json['cookName'] as String?,
      phone: json['phone'] as String,
      status: json['status'] as String,
      zoneId: json['zoneId'] as String?,
      addressLine: json['addressLine'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      story: json['story'] as String?,
      signatureDish: json['signatureDish'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kitchenName': kitchenName,
      'cookName': cookName,
      'phone': phone,
      'status': status,
      'zoneId': zoneId,
      'addressLine': addressLine,
      'lat': lat,
      'lng': lng,
      'story': story,
      'signatureDish': signatureDish,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Kitchen(id: $id, kitchenName: $kitchenName)';
}
