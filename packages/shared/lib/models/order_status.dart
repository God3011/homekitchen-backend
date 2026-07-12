/// Mirrors the backend Prisma `OrderStatus` enum exactly.
/// Keep in sync with prisma/schema.prisma.
enum OrderStatus {
  received,
  preparing,
  ready,
  customer_en_route,
  customer_arrived,
  out_for_delivery,
  completed,
  rejected,
  cancelled;

  /// Parse from the snake_case string returned by the API.
  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown OrderStatus: $value'),
    );
  }

  /// Serialize to the snake_case string the API expects.
  String toJson() => name;
}
