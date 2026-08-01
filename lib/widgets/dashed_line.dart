import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';

/// Linea tratteggiata orizzontale stile scontrino, usata dentro le card
/// biglietto (CSS design: `border: 1px dashed #FFFFFF`; dash ~6px, gap ~4px
/// come nel PNG ufficiale). La larghezza è in px design e scala con [R.sp].
class DashedLine extends StatelessWidget {
  final double widthDesign;
  final Color color;

  const DashedLine({
    Key? key,
    required this.widthDesign,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: R.sp(widthDesign),
      height: R.sp(1),
      child: CustomPaint(painter: _DashedLinePainter(color)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final dash = R.sp(6);
    final gap = R.sp(4);
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
