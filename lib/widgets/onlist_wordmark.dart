import 'package:flutter/material.dart';

import '../core/constants/image_constant.dart';

/// Scritta "OnList" (wordmark ufficiale), ritagliata dal suo asset.
///
/// `logo_onlist_wordmark.png` NON è ritagliato: è un canvas QUADRATO in cui la
/// scritta occupa solo una fascia centrale, circondata da molto spazio
/// trasparente. Disegnarlo con un semplice `Image.asset(height: h)` fa quindi
/// una scritta alta `h × 0.2535` — un quarto di quello che ci si aspetta —
/// persa dentro un riquadro quasi vuoto.
///
/// Qui il ritaglio è fatto a runtime con OverflowBox + Transform (nessuna
/// modifica al file su disco): il box finale è esattamente la scritta.
///
/// Le percentuali sono il bounding box dei pixel PIENI delle lettere, con un
/// po' di headroom in alto per non tagliare il glow viola del puntino della
/// "i", che sfora sopra la cap-height.
///
/// Era codice privato di `CustomTopBar`: estratto qui quando è servito anche
/// alla card "Tu e OnList", dove il logo era appunto finito minuscolo.
class OnlistWordmark extends StatelessWidget {
  const OnlistWordmark({super.key, required this.height});

  /// Altezza REALE della scritta (non del canvas): è ciò che si vede.
  final double height;

  static const double _cropLeft = 0.1237;
  static const double _cropTop = 0.3950;
  static const double _cropWidth = 0.7520;
  static const double _cropHeight = 0.2535;

  /// Proporzioni della sola scritta: ~2.97:1.
  static double get aspect => _cropWidth / _cropHeight;

  @override
  Widget build(BuildContext context) {
    final double boxW = height * aspect;
    // Lato del render quadrato: la frazione _cropHeight del lato deve
    // corrispondere all'altezza voluta.
    final double side = height / _cropHeight;
    return ClipRect(
      child: SizedBox(
        width: boxW,
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: side,
          maxWidth: side,
          minHeight: side,
          maxHeight: side,
          child: Transform.translate(
            offset: Offset(-_cropLeft * side, -_cropTop * side),
            child: Image.asset(
              ImageConstant.imgLogoOnlistWordmark,
              width: side,
              height: side,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}
