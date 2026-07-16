import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/api_provider.dart';
import '../providers/orders_provider.dart';

/// Star-rating + optional comment sheet. Submits POST /orders/:id/rating.
/// Returns true if a rating was submitted.
Future<bool> showRateSheet(
  BuildContext context,
  WidgetRef ref, {
  required String orderId,
  required String kitchenId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RateSheet(orderId: orderId, kitchenId: kitchenId),
  );
  return result ?? false;
}

class _RateSheet extends ConsumerStatefulWidget {
  const _RateSheet({required this.orderId, required this.kitchenId});
  final String orderId;
  final String kitchenId;

  @override
  ConsumerState<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends ConsumerState<_RateSheet> {
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = 'Tap a star to rate.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final comment = _commentController.text.trim();
      await ref.read(apiClientProvider).post('/orders/${widget.orderId}/rating',
          body: {
            'stars': _stars,
            if (comment.isNotEmpty) 'comment': comment,
          });
      trackEvent('rating_submitted', {
        'order_id': widget.orderId,
        'kitchen_id': widget.kitchenId,
        'rating_value': _stars,
      });
      ref.invalidate(orderProvider(widget.orderId));
      ref.invalidate(ordersHistoryProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Could not submit rating.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your order',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  icon: Icon(
                    i <= _stars ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade700,
                    size: 36,
                  ),
                  onPressed: () => setState(() => _stars = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Add a comment (optional)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit rating'),
          ),
        ],
      ),
    );
  }
}
