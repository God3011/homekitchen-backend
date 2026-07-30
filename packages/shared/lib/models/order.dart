import 'order_status.dart';
import 'kitchen.dart';
import 'rating.dart';

/// A single preference on an order item (snapshot from menu).
///
/// The backend row has a composite primary key `(orderItemId, preference)` and
/// therefore NO `id` field — so `id` here is nullable. Reading it as a non-null
/// String was a latent bug that crashed parsing of any order carrying item
/// preferences ("type 'Null' is not a subtype of type 'String'").
class OrderItemPreference {
  final String? id;
  final String preference;

  const OrderItemPreference({
    this.id,
    required this.preference,
  });

  factory OrderItemPreference.fromJson(Map<String, dynamic> json) {
    return OrderItemPreference(
      id: json['id'] as String?,
      preference: json['preference'] as String,
    );
  }

}

/// A line item within an order. Name and price are snapshotted at order time
/// so later menu edits never rewrite order history.
class OrderItem {
  final String id;
  final String menuItemId;
  final String itemName;
  final int unitPricePaise;
  final int quantity;
  final List<OrderItemPreference> preferences;

  const OrderItem({
    required this.id,
    required this.menuItemId,
    required this.itemName,
    required this.unitPricePaise,
    required this.quantity,
    this.preferences = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      menuItemId: json['menuItemId'] as String,
      itemName: json['itemName'] as String,
      unitPricePaise: json['unitPricePaise'] as int,
      quantity: json['quantity'] as int,
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) =>
                  OrderItemPreference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

}

/// Payment info attached to an order.
/// Amount is in paise (integers).
class Payment {
  final String id;
  final int amountPaise;
  final String status; // 'created' | 'authorized' | 'captured' | 'failed' | 'refunded'

  const Payment({
    required this.id,
    required this.amountPaise,
    required this.status,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      amountPaise: json['amountPaise'] as int,
      status: json['status'] as String,
    );
  }

}

/// Order model — mirrors the backend Order entity.
/// All money fields are in paise (integers). Format to rupees only at display time.
class Order {
  final String id;
  final String customerId;
  final String kitchenId;
  final String fulfillment; // 'pickup' | 'delivery'
  final OrderStatus status;
  final int foodTotalPaise;
  final int platformFeePaise;
  final int deliveryFeePaise;
  final int grandTotalPaise;
  final int? etaMinutes;
  // Null on seller-facing responses — the code is only ever sent to the
  // customer (proof of pickup). The seller enters what the customer tells them.
  final String? handoverCode;
  final DateTime placedAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final String? rejectReason;
  final String? cancelReason;
  final List<OrderItem> items;
  final Payment? payment;
  // Present when the endpoint joins the kitchen / rating (order detail).
  final Kitchen? kitchen;
  final Rating? rating;

  const Order({
    required this.id,
    required this.customerId,
    required this.kitchenId,
    required this.fulfillment,
    required this.status,
    required this.foodTotalPaise,
    required this.platformFeePaise,
    required this.deliveryFeePaise,
    required this.grandTotalPaise,
    this.etaMinutes,
    this.handoverCode,
    required this.placedAt,
    this.acceptedAt,
    this.readyAt,
    this.completedAt,
    this.rejectReason,
    this.cancelReason,
    this.items = const [],
    this.payment,
    this.kitchen,
    this.rating,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      kitchenId: json['kitchenId'] as String,
      fulfillment: json['fulfillment'] as String,
      status: OrderStatus.fromString(json['status'] as String),
      foodTotalPaise: json['foodTotalPaise'] as int,
      platformFeePaise: json['platformFeePaise'] as int,
      deliveryFeePaise: json['deliveryFeePaise'] as int,
      grandTotalPaise: json['grandTotalPaise'] as int,
      etaMinutes: json['etaMinutes'] as int?,
      handoverCode: json['handoverCode'] as String?,
      placedAt: DateTime.parse(json['placedAt'] as String),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'] as String)
          : null,
      readyAt: json['readyAt'] != null
          ? DateTime.parse(json['readyAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      rejectReason: json['rejectReason'] as String?,
      cancelReason: json['cancelReason'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      payment: json['payment'] != null
          ? Payment.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
      kitchen: json['kitchen'] != null
          ? Kitchen.fromJson(json['kitchen'] as Map<String, dynamic>)
          : null,
      rating: json['rating'] != null
          ? Rating.fromJson(json['rating'] as Map<String, dynamic>)
          : null,
    );
  }


  @override
  String toString() => 'Order(id: $id, status: $status, grandTotalPaise: $grandTotalPaise)';
}
