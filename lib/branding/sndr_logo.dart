import 'package:flutter/material.dart';

/// SNDR Logo — gift box with square lid + geometric bow + wordmark (or monogram).
class SndrLogo extends StatelessWidget {
  const SndrLogo({
    super.key,
    this.height = 48,
    this.color,
    this.accentColor,
    this.showWordmark = true,
    this.fontWeight = FontWeight.w600,
    this.letterSpacing = -0.2,
    this.monogram = 's',

    /// Box styling
    this.boxCorner = 0.0, // default square
    this.boxStroke = 5.0,
    this.boxPad = 12.0,
  });

  final double height;
  final Color? color;
  final Color? accentColor;

  final bool showWordmark;
  final FontWeight fontWeight;
  final double letterSpacing;
  final String monogram;

  final double boxCorner;
  final double boxStroke;
  final double boxPad;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final a = accentColor ?? c.withValues(alpha: 0.65);
    return _AutoWidthPainterBox(
      height: height,
      painterBuilder: (size) => _SndrLogoPainter(
        color: c,
        accent: a,
        showWordmark: showWordmark,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        monogram: monogram,
        boxCorner: boxCorner,
        boxStroke: boxStroke,
        boxPad: boxPad,
      ),
    );
  }
}

class _AutoWidthPainterBox extends StatelessWidget {
  const _AutoWidthPainterBox({
    required this.height,
    required this.painterBuilder,
  });

  final double height;
  final CustomPainter Function(Size size) painterBuilder;

  @override
  Widget build(BuildContext context) {
    final provisional = Size(height * 8, height);
    final painter = painterBuilder(provisional) as _SndrLogoPainter;
    final width = painter.computeWidth(provisional);
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: painter),
      ),
    );
  }
}

class _SndrLogoPainter extends CustomPainter {
  _SndrLogoPainter({
    required this.color,
    required this.accent,
    required this.showWordmark,
    required this.fontWeight,
    required this.letterSpacing,
    required this.monogram,
    required this.boxCorner,
    required this.boxStroke,
    required this.boxPad,
  });

  final Color color;
  final Color accent;
  final bool showWordmark;
  final FontWeight fontWeight;
  final double letterSpacing;
  final String monogram;

  final double boxCorner;
  final double boxStroke;
  final double boxPad;

  static const double _designH = 100.0;
  static const double _textH = 62.0;

  double _computedWidth = 0;

  TextPainter _buildTextPainter(double scale) {
    final fontSize = _textH * scale * 0.88;
    final text = showWordmark ? 'sndr' : monogram;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp;
  }

  double computeWidth(Size outSize) {
    final scale = outSize.height / _designH;
    final tp = _buildTextPainter(scale);
    final lip = 12.0 * scale;
    final horizontal = (boxPad * 2 * scale) + (lip * 2);
    _computedWidth = tp.width + horizontal;
    return _computedWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _designH;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = boxStroke * scale
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    final accentStroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = (boxStroke * 0.45) * scale
      ..strokeCap = StrokeCap.square;

    final tp = _buildTextPainter(scale);
    final textW = tp.width;
    final textH = tp.height;

    final centerY = size.height * 0.56;
    final boxH = textH * 1.28;
    final lidH = boxStroke * 2.0 * scale;
    final lip = 12.0 * scale;
    final innerPad = boxPad * scale;

    final contentW = textW + innerPad * 2;
    final boxW = contentW + lip * 2;
    final left = (size.width - boxW) / 2;
    final top = centerY - boxH / 2;

    // Box body
    final bodyRect = Rect.fromLTWH(left, top, boxW, boxH);
    canvas.drawRect(bodyRect, stroke);

    // Lid
    final lidRect = Rect.fromLTWH(left, top - lidH, boxW, lidH);
    canvas.drawRect(lidRect, stroke);

    // Accent line
    final accentY = top + (boxStroke * 0.9) * scale;
    canvas.drawLine(
      Offset(left + boxStroke * scale, accentY),
      Offset(left + boxW - boxStroke * scale, accentY),
      accentStroke,
    );

    // Text
    final textLeft = (size.width - textW) / 2;
    final textTop = centerY - (tp.height * 0.66);
    tp.paint(canvas, Offset(textLeft, textTop));

    // Geometric bow
    final knotY = top - lidH - (boxStroke * 0.3) * scale;
    final bowW = (contentW * 0.35).clamp(16.0 * scale, 42.0 * scale);
    final bowH = bowW * 0.55;
    final loopThickness = (boxStroke * 0.8) * scale;

    final bowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = loopThickness
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    final loopW = bowW * 0.70;
    final loopH = bowH * 0.42;
    final loopR = 0.0; // perfectly sharp corners
    final theta = 92 * 3.14159265 / 180;

    final cx = size.width / 2;

    // Left loop
    canvas.save();
    canvas.translate(cx - bowW * 0.48, knotY + bowH * 0.20);
    canvas.rotate(-theta);
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: loopW, height: loopH),
      Radius.circular(loopR),
    );
    canvas.drawRRect(leftRect, bowPaint);
    canvas.restore();

    // Right loop
    canvas.save();
    canvas.translate(cx + bowW * 0.48, knotY + bowH * 0.20);
    canvas.rotate(theta);
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: loopW, height: loopH),
      Radius.circular(loopR),
    );
    canvas.drawRRect(rightRect, bowPaint);
    canvas.restore();

    // Knot bar
    final knotLen = (boxStroke * 1.6) * scale;
    canvas.drawLine(
      Offset(cx - knotLen / 2, knotY),
      Offset(cx + knotLen / 2, knotY),
      bowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SndrLogoPainter old) {
    return color != old.color ||
        accent != old.accent ||
        showWordmark != old.showWordmark ||
        fontWeight != old.fontWeight ||
        letterSpacing != old.letterSpacing ||
        monogram != old.monogram ||
        boxCorner != old.boxCorner ||
        boxStroke != old.boxStroke ||
        boxPad != old.boxPad;
  }
}
