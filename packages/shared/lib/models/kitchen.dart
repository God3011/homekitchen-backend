/// Kitchen model — mirrors the backend Kitchen entity.
class Kitchen {
  final String id;
  final String kitchenName;
  final String? cookName;
  final String? cookPhotoUrl;
  final List<String> kitchenPhotoUrls;
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
  // Server-computed rating summary (present on the customer detail endpoint).
  final double? ratingAvg;
  final int ratingCount;
  // Straight-line distance from the caller, when GPS was supplied.
  final int? distanceM;

  const Kitchen({
    required this.id,
    required this.kitchenName,
    this.cookName,
    this.cookPhotoUrl,
    this.kitchenPhotoUrls = const [],
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
    this.ratingAvg,
    this.ratingCount = 0,
    this.distanceM,
  });

  factory Kitchen.fromJson(Map<String, dynamic> json) {
    return Kitchen(
      id: json['id'] as String,
      kitchenName: json['kitchenName'] as String,
      cookName: json['cookName'] as String?,
      cookPhotoUrl: json['cookPhotoUrl'] as String?,
      kitchenPhotoUrls:
          (json['kitchenPhotoUrls'] as List<dynamic>?)?.cast<String>() ??
              const [],
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
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      ratingCount: json['ratingCount'] as int? ?? 0,
      distanceM: json['distanceM'] as int?,
    );
  }


  @override
  String toString() => 'Kitchen(id: $id, kitchenName: $kitchenName)';
}
