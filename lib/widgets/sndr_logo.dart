import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SndrLogoNew extends StatelessWidget {
  const SndrLogoNew({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    // Prefer SVG (sharp at any size); fall back to PNG if needed.
    return Image.asset(
      'assets/images/sndr_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // If SVG ever fails to load, you can swap to Image.asset here.
    );
  }
}

class SndrLogo extends StatelessWidget {
  const SndrLogo({
    super.key,
    this.fontSize = 22,
    this.tightness = 0.01,
    this.showRibbon = true,
  });

  final double fontSize;
  final double tightness;
  final bool showRibbon;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bow painter with its own slight downward nudge
        Transform.translate(
          offset: Offset(
            0,
            fontSize * 0.08 * -0.01,
          ), // negative pushes bow closer
          child: CustomPaint(
            size: Size(fontSize * 1.28, fontSize * 0.46),
            painter: _BowWithRibbonPainter(color, showRibbon: showRibbon),
          ),
        ),
        Text(
          '[sndr]',
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BowWithRibbonPainter extends CustomPainter {
  _BowWithRibbonPainter(this.color, {required this.showRibbon});
  final Color color;
  final bool showRibbon;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = h * 0.22; // thicker ribbon lines
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // left loop
    final left = Path()
      ..moveTo(w * 0.42, h * 0.55)
      ..cubicTo(w * 0.33, h * 0.10, w * 0.10, h * 0.10, w * 0.05, h * 0.55)
      ..cubicTo(w * 0.10, h * 0.95, w * 0.45, h * 0.95, w * 0.42, h * 0.55);
    canvas.drawPath(left, paint);

    // right loop (mirror of left)
    final right = Path()
      ..moveTo(w * 0.58, h * 0.55)
      ..cubicTo(w * 0.67, h * 0.10, w * 0.90, h * 0.10, w * 0.95, h * 0.55)
      ..cubicTo(w * 0.90, h * 0.95, w * 0.55, h * 0.95, w * 0.58, h * 0.55);
    canvas.drawPath(right, paint);

    // knot
    final knot = Paint()..color = color;
    final r = h * 0.22;
    canvas.drawCircle(Offset(w * 0.50, h * 0.52), r, knot);

    // ribbon line
    if (showRibbon) {
      final ribbonH = h * 0.16;
      final y = h * 0.90;
      final rect = RRect.fromRectXY(
        Rect.fromLTWH(w * 0.00, y - ribbonH / 2, w * 1, ribbonH),
        ribbonH / 2,
        ribbonH / 2,
      );
      final fill = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _BowWithRibbonPainter old) =>
      old.color != color || old.showRibbon != showRibbon;
}
