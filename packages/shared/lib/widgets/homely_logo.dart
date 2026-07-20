import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The Homely mark: a home whose roof rises like steam over a warm bowl — trust
/// blue for the house, turmeric gold for the food. Drawn with a painter so it
/// stays crisp at any size and needs no bundled asset. Set [onBlue] for the
/// reversed treatment used on a blue ground (e.g. the app icon).
class HomelyLogoMark extends StatelessWidget {
  const HomelyLogoMark({super.key, this.size = 40, this.onBlue = false});

  final double size;
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter(onBlue: onBlue)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.onBlue});
  final bool onBlue;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;
    final houseColor = onBlue ? HomelyColors.cream : HomelyColors.blueDeep;
    final steamColor = onBlue ? HomelyColors.blueDeep : HomelyColors.cream;

    // House pentagon: peak at top, square body with softly rounded base.
    final house = Path()
      ..moveTo(24 * s, 5 * s)
      ..lineTo(42 * s, 19.5 * s)
      ..lineTo(42 * s, 38.8 * s)
      ..arcToPoint(Offset(38.8 * s, 42 * s),
          radius: Radius.circular(3.2 * s), clockwise: true)
      ..lineTo(9.2 * s, 42 * s)
      ..arcToPoint(Offset(6 * s, 38.8 * s),
          radius: Radius.circular(3.2 * s), clockwise: true)
      ..lineTo(6 * s, 19.5 * s)
      ..close();
    canvas.drawPath(house, Paint()..color = houseColor);

    // Bowl: a warm half-ellipse.
    final bowl = Path()
      ..moveTo(14.5 * s, 29 * s)
      ..lineTo(33.5 * s, 29 * s)
      ..arcToPoint(Offset(14.5 * s, 29 * s),
          radius: Radius.elliptical(9.5 * s, 7.6 * s), clockwise: true)
      ..close();
    canvas.drawPath(bowl, Paint()..color = HomelyColors.gold);

    // Three steam wisps rising from the bowl.
    final steam = Paint()
      ..color = steamColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * s
      ..strokeCap = StrokeCap.round;
    for (final x in [20.0, 24.0, 28.0]) {
      final wisp = Path()
        ..moveTo(x * s, 25.6 * s)
        ..relativeCubicTo(
            -1.7 * s, -1.7 * s, -1.7 * s, -3.0 * s, 0, -4.7 * s);
      canvas.drawPath(wisp, steam);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.onBlue != onBlue;
}

/// The "Homely" wordmark (Poppins, with "ly" in gold). Use on its own under the
/// mark, or inside [HomelyLogo] beside it.
class HomelyWordmark extends StatelessWidget {
  const HomelyWordmark({super.key, this.fontSize = 24});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: HomelyColors.ink,
        ),
        children: const [
          TextSpan(text: 'Home'),
          TextSpan(text: 'ly', style: TextStyle(color: HomelyColors.goldDeep)),
        ],
      ),
    );
  }
}

/// The full horizontal lockup: mark + wordmark.
class HomelyLogo extends StatelessWidget {
  const HomelyLogo({super.key, this.markSize = 34, this.fontSize = 24});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HomelyLogoMark(size: markSize),
        SizedBox(width: markSize * 0.28),
        HomelyWordmark(fontSize: fontSize),
      ],
    );
  }
}
