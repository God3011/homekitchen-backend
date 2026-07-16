import 'package:flutter/material.dart';

/// Compact rating display: a star icon + average and count.
/// Shows "New" when a kitchen has no ratings yet.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.average,
    required this.count,
    this.size = 16,
  });

  final double? average;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (average == null || count == 0) {
      return Text('New',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: size, color: Colors.amber.shade700),
        const SizedBox(width: 2),
        Text(average!.toStringAsFixed(1),
            style: TextStyle(fontSize: size - 2, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text('($count)',
            style: TextStyle(fontSize: size - 3, color: Colors.grey)),
      ],
    );
  }
}

/// Turns a preference enum value (e.g. "less_spicy") into a friendly label.
String prettyPreference(String pref) {
  return pref
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
