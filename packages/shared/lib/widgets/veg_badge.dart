import 'package:flutter/material.dart';

/// The standard Indian veg / non-veg marker: a small square outline enclosing a
/// filled dot — green for veg, red-brown for non-veg. Shared by both apps so the
/// symbol is identical everywhere it appears (menu rows, cart, kitchen editor).
class VegBadge extends StatelessWidget {
  const VegBadge({super.key, required this.isVeg, this.size = 16});

  final bool isVeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Sage green for veg; a warm brick red for non-veg — both legible on cream.
    final color = isVeg ? const Color(0xFF5C8570) : const Color(0xFFB4472F);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Container(
          width: size * 0.45,
          height: size * 0.45,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Compact "Veg only" filter toggle used on the discovery list and a kitchen's
/// menu. Green when active. The caller owns the boolean and filters its list.
class VegOnlyToggle extends StatelessWidget {
  const VegOnlyToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Veg',
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF5C8570);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value ? green.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: value ? green : Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VegBadge(isVeg: true, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: value ? green : Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}
