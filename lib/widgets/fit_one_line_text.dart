import 'package:flutter/material.dart';

/// Testo su UNA riga che si rimpicciolisce per starci, senza scendere sotto
/// [minFontSize]; oltre quel limite si tronca con i puntini.
///
/// A differenza di `FittedBox`, un testo lunghissimo non diventa illeggibile.
/// Le dimensioni del [style] e [minFontSize] sono px reali (già scalati).
class FitOneLineText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double minFontSize;
  final TextAlign textAlign;

  const FitOneLineText(
    this.text, {
    super.key,
    required this.style,
    required this.minFontSize,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final double maxSize = style.fontSize ?? 14;
      double size = maxSize;
      while (size > minFontSize) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: _styleAt(size, maxSize)),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final bool fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        if (fits) break;
        size -= 1;
      }
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: _styleAt(size < minFontSize ? minFontSize : size, maxSize),
      );
    });
  }

  /// Il letter-spacing scala con il corpo, così la spaziatura in em resta.
  TextStyle _styleAt(double size, double maxSize) => style.copyWith(
        fontSize: size,
        letterSpacing: style.letterSpacing == null
            ? null
            : style.letterSpacing! * size / maxSize,
      );
}
