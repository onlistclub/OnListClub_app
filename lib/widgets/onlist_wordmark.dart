import 'package:flutter/material.dart';

import '../core/constants/image_constant.dart';

/// Logo "OnList" intero (scritta + pallina con l'alone), versione bianca.
///
/// Usa l'asset ufficiale `WHITE INTERO.png` della cartella brand, già
/// ritagliato sui bordi effettivi della grafica (variante "Senza Margini"):
/// niente più canvas quadrato con metà disegno trasparente attorno.
///
/// **Perché non c'è nessun ritaglio.** Prima il logo veniva ricavato da un
/// asset quadrato con un `ClipRect` sul riquadro delle sole lettere piene: e
/// quel riquadro tagliava l'alone viola della pallina, che sfora sopra la
/// cap-height (punto 1.2 del documento "Specifiche Modifiche App"). Qui il
/// disegno esce liberamente dal riquadro di layout, che resta grande quanto
/// la scritta: il logo occupa lo stesso spazio di prima e l'alone si vede
/// tutto.
///
/// [height] è l'altezza delle LETTERE — quello che l'occhio misura — non del
/// riquadro dell'immagine: l'alone non fa testo nell'allineamento.
class OnlistWordmark extends StatelessWidget {
  const OnlistWordmark({super.key, required this.height});

  /// Altezza della scritta, alone escluso.
  final double height;

  // Misure prese sui pixel di `WHITE INTERO.png` (1500×635):
  //  - lettere piene: x 0…1498, y 180…633 → 1499×454;
  //  - disegno completo (alone incluso): y 30…634.
  // L'alone sfora quindi solo SOPRA le lettere, per 150px su 454.
  static const double _assetW = 1500;
  static const double _assetH = 635;
  static const double _lettereW = 1499;
  static const double _lettereH = 454;
  static const double _lettereTop = 180;

  /// Quante volte l'immagine intera è più alta delle sole lettere.
  static const double _scala = _assetH / _lettereH; // 1.3987

  /// Quanto l'immagine sfora sopra il riquadro, in multipli di [height].
  static const double _sforoSopra = (_lettereTop / _assetH) * _scala; // 0.3964

  /// Proporzioni della sola scritta: ~3.30:1.
  static double get aspect => _lettereW / _lettereH;

  @override
  Widget build(BuildContext context) {
    final double imgH = height * _scala;
    final double imgW = imgH * (_assetW / _assetH);
    return SizedBox(
      // Il posto occupato nel layout è quello della scritta, come prima.
      width: height * aspect,
      height: height,
      child: OverflowBox(
        // Niente clip: l'immagine è più alta del riquadro e la parte in
        // eccesso — l'alone — viene disegnata fuori, sopra.
        alignment: Alignment.topLeft,
        minWidth: imgW,
        maxWidth: imgW,
        minHeight: imgH,
        maxHeight: imgH,
        child: Transform.translate(
          offset: Offset(0, -_sforoSopra * height),
          child: Image.asset(
            ImageConstant.imgLogoOnlistIntero,
            width: imgW,
            height: imgH,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}
