import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/payment_service.dart';
import '../widgets/rating_stars.dart';
import 'order_tracking_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _placing = false;
  String? _error;

  /// Place the order, create the Razorpay order, run checkout, and route to
  /// tracking. The order exists as soon as `POST /orders` returns — if payment
  /// fails the customer can retry from the tracking screen.
  Future<void> _placeAndPay(Cart cart) async {
    setState(() {
      _placing = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    PaymentService? payment;
    try {
      trackEvent('checkout_started', {
        'cart_value': cart.grandTotalPaise,
        'item_count': cart.itemCount,
        'kitchen_id': cart.kitchenId,
      });

      // 1. Create the order (snapshots prices, decrements plates server-side).
      final orderRes = await api.post('/orders', body: {
        'kitchenId': cart.kitchenId,
        'fulfillment': 'pickup',
        'items': cart.lines.map((l) => l.toOrderItemJson()).toList(),
      });
      final orderId = orderRes['id'] as String;

      // NOTE: `order_placed` is a purchase event — it fires only AFTER payment
      // is confirmed (below), never here. Firing before payment would count
      // abandoned/failed checkouts as purchases.

      // 2. Create the Razorpay order.
      final rp = await api
          .post('/payments/$orderId/razorpay-order');
      final keyId = rp['keyId'] as String?;

      // If Razorpay keys aren't configured yet, skip checkout and just show
      // the order — payment can be completed later.
      if (keyId == null || keyId.isEmpty) {
        _goToTracking(orderId);
        return;
      }

      // 3. Open checkout.
      final phone = ref.read(customerProfileProvider).valueOrNull?.phone;
      payment = PaymentService(api);
      final outcome = await payment.pay(
        keyId: keyId,
        razorpayOrderId: rp['razorpayOrderId'] as String,
        amountPaise: rp['amountPaise'] as int,
        kitchenName: cart.kitchenName,
        contactPhone: phone,
      );

      if (outcome != PaymentOutcome.success) {
        // Razorpay handles retry inside its own sheet; a non-success outcome
        // only reaches us once the user has fully closed the gateway — i.e.
        // they've given up. So cancel the unpaid order immediately (restores
        // plates) and drop them back on the menu with their cart intact, so
        // ordering again is easy. The server TTL sweep is the backstop if this
        // cancel call doesn't land.
        try {
          await api.patch('/orders/$orderId/cancel', body: {
            'reason': outcome == PaymentOutcome.failed
                ? 'Payment failed'
                : 'Payment not completed',
          });
        } catch (_) {/* TTL sweep will clean it up */}
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(); // back to the kitchen menu (cart preserved)
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Payment not completed — your order was cancelled. Your cart is saved; tap it to try again.'),
        ));
        return;
      }

      // Paid → payment confirmed server-side (verify + webhook backstop).
      // This is the only place `order_placed` fires.
      trackEvent('order_placed', {
        'order_id': orderId,
        'value': cart.grandTotalPaise,
        'currency': 'INR',
        'kitchen_id': cart.kitchenId,
        'order_type': 'pickup',
      });

      // Paid → show the live order.
      _goToTracking(orderId);
    } catch (e) {
      setState(() {
        _placing = false;
        _error = 'Could not place order: $e';
      });
    } finally {
      payment?.dispose();
    }
  }

  void _goToTracking(String orderId) {
    ref.read(cartProvider.notifier).clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    if (cart == null || cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your cart')),
        body: const Center(child: Text('Your cart is empty.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(cart.kitchenName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final line in cart.lines) _CartLineTile(line: line),
          const Divider(height: 32),
          _TotalRow(label: 'Food total', paise: cart.foodTotalPaise),
          _TotalRow(label: 'Platform fee', paise: cart.platformFeePaise),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pickup'),
                Text('FREE',
                    style: TextStyle(
                        color: HomelyColors.sageDeep,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _TotalRow(
            label: 'To pay',
            paise: cart.grandTotalPaise,
            emphasize: true,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            style: HomelyStyles.accentButton,
            onPressed: _placing ? null : () => _placeAndPay(cart),
            child: _placing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Place order · ${formatPaise(cart.grandTotalPaise)}'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pickup only. You will pay securely via UPI.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.itemName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(formatPaise(line.unitPricePaise),
                    style: Theme.of(context).textTheme.bodySmall),
                if (line.preferences.isNotEmpty)
                  Text(line.preferences.map(prettyPreference).join(' · '),
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => notifier.decrement(line.menuItemId),
              ),
              Text('${line.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => notifier.increment(line.menuItemId),
              ),
            ],
          ),
          SizedBox(
            width: 64,
            child: Text(formatPaise(line.lineTotalPaise),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.paise,
    this.emphasize = false,
  });

  final String label;
  final int paise;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatPaise(paise), style: style),
        ],
      ),
    );
  }
}
