/// Rating model — mirrors the backend Rating entity.
///
/// The kitchen-detail endpoint returns a trimmed shape ({stars, comment,
/// createdAt}) with no ids, so [id]/[orderId]/[kitchenId] are nullable.
class Rating {
  final String? id;
  final String? orderId;
  final String? kitchenId;
  final int stars;
  final String? comment;
  final DateTime createdAt;

  const Rating({
    this.id,
    this.orderId,
    this.kitchenId,
    required this.stars,
    this.comment,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as String?,
      orderId: json['orderId'] as String?,
      kitchenId: json['kitchenId'] as String?,
      stars: json['stars'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'kitchenId': kitchenId,
      'stars': stars,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
