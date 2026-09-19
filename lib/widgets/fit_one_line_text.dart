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
      // Con crenatura negativa (i titoli del design hanno -0.1em) Flutter
      // sottrae lo spazio anche DOPO l'ultima lettera: il testo disegna più
      // largo della sua scatola e chi lo contiene gli taglia l'ultima lettera.
      // Lo spazio perso va restituito a destra; siccome il disegno sborda solo
      // da quel lato, il padding riporta al centro anche il testo centrato.
      // Oltre alla crenatura si lascia un filo per la parte di glifo che
      // sborda a destra (la "b" di "Goa Club", la "n" di "Peter Pan"): senza,
      // l'ultima lettera restava tagliata di un pelo.
      double coda(double s) {
        final ls = style.letterSpacing;
        final double crenatura = (ls == null || ls >= 0) ? 0 : -ls * s / maxSize;
        return crenatura + s * 0.04;
      }

      final double disponibile = constraints.maxWidth - coda(maxSize);
      while (size > minFontSize) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: _styleAt(size, maxSize)),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final bool fits = painter.width <= disponibile;
        painter.dispose();
        if (fits) break;
        size -= 1;
      }
      final double finale = size < minFontSize ? minFontSize : size;
      return Padding(
        padding: EdgeInsets.only(right: coda(finale)),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: _styleAt(finale, maxSize),
        ),
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
