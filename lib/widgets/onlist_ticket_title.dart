import 'package:flutter/material.dart';

/// Titolo "Ticket" con il tipo ("Normale"/"Vip"/"Uomo") ancorato sotto la "k".
///
/// Nel Figma il tipo non è indentato di una misura arbitraria: parte esatta-
/// mente dal bordo sinistro del glifo "k" di "Ticket" (verificato su due frame,
/// Δ 0.98em e 0.94em dal titolo, contro gli 0.978em teorici delle avanzate
/// Helvetica con crenatura -0.1em).
///
/// Quel punto non è calcolabile a priori: dipende da come il font disponibile
/// sul device rende la parola, e il fallback cambia (SF Pro su iOS, Roboto su
/// Android). Per questo la "k" viene misurata a runtime con un TextPainter
/// sulla parola vera, invece di usare un offset fisso: l'ancoraggio resta
/// corretto su qualsiasi device e a qualsiasi fontSize.
class OnlistTicketTitle extends StatelessWidget {
  const OnlistTicketTitle({
    super.key,
    required this.type,
    required this.titleStyle,
    required this.typeStyle,
    required this.typeTopEm,
  });

  /// Tipo già formattato per la UI (es. "Normale").
  final String type;
  final TextStyle titleStyle;
  final TextStyle typeStyle;

  /// Distanza verticale top-to-top tra "Ticket" e il tipo, in em del titolo.
  /// Espressa come frazione del fontSize, mai in pixel.
  final double typeTopEm;

  static const String _title = 'Ticket';

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    final titlePainter = TextPainter(
      text: TextSpan(text: _title, style: titleStyle),
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    // Caret prima della "k": il suo bordo sinistro reale, kerning incluso.
    final kDx = titlePainter
        .getOffsetForCaret(
          TextPosition(offset: _title.indexOf('k')),
          Rect.zero,
        )
        .dx;

    final typePainter = TextPainter(
      text: TextSpan(text: type, style: typeStyle),
      textDirection: direction,
      textScaler: textScaler,
    )..layout();

    final typeTop = textScaler.scale(titleStyle.fontSize ?? 0) * typeTopEm;
    final typeHeight =
        textScaler.scale(typeStyle.fontSize ?? 0) * (typeStyle.height ?? 1);
    // Dimensioni esplicite: il tipo è Positioned e non misura lo Stack, ma il
    // gruppo deve occupare lo spazio vero per non far ballare il resto.
    final width = titlePainter.width > kDx + typePainter.width
        ? titlePainter.width
        : kDx + typePainter.width;

    titlePainter.dispose();
    typePainter.dispose();

    return SizedBox(
      width: width,
      height: typeTop + typeHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(_title, style: titleStyle),
          Positioned(
            left: kDx,
            top: typeTop,
            child: Text(type, style: typeStyle),
          ),
        ],
      ),
    );
  }
}
