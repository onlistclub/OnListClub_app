import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/constants/image_constant.dart';
import '../core/services/navigator_service.dart';
import '../core/utils/responsive.dart';
import '../theme/onlist_text_styles.dart';

/// Riga "← Torna indietro", unica per tutta l'app.
///
/// Prima ogni schermata se la ridisegnava da sola, e infatti erano diverse fra
/// loro: `Icons.arrow_back` a 28 quasi ovunque, a 20 nel dettaglio tavolo, e
/// `Icons.arrow_back_ios_new` nella ricerca locali. In più la freccia Material
/// risultava più piccola del testo, che è 32.
///
/// Qui la freccia è l'SVG ufficiale (`freccia_sinistra.svg`) a [_arrowSize],
/// dimensionata per stare alla pari col testo `title32Light`.
class BackRow extends StatelessWidget {
  const BackRow({
    super.key,
    this.label = 'Torna indietro',
    this.onTap,
    this.padding,
  });

  /// Testo accanto alla freccia.
  final String label;

  /// Azione al tap. Se null si torna indietro nello stack di navigazione.
  final VoidCallback? onTap;

  /// Margini della riga. Default: quelli usati dalla maggior parte delle
  /// schermate (12 ai lati, 12 sopra, 8 sotto).
  final EdgeInsetsGeometry? padding;

  /// Dimensione della freccia, in px design.
  ///
  /// **24, non 34.** Il CSS dichiara un riquadro `arrow_back` di 36×36 con
  /// dentro l'icona al 16.67% per lato: il glifo vero è 36 × 0.6667 = **24**,
  /// che è anche la dimensione nativa di `freccia_sinistra.svg`. Disegnarla a
  /// 34 la gonfiava del 42% e la faceva sembrare più grossa della scritta
  /// (correzioni 1.11): quel 34 era una mia correzione di troppo al punto 3
  /// della 1.1, dove la freccia risultava invece troppo piccola.
  static const double _arrowSize = 24;

  /// Spazio fra freccia e testo. CSS: glifo da 20 a 44, testo a 50.
  static const double _gap = 6;

  /// Margine sinistro della riga: il glifo parte a 20 (riquadro a left 14 più
  /// i 6 di inset), non a 12.
  static const double _leftDesign = 20;

  @override
  Widget build(BuildContext context) {
    // Ancorata a SINISTRA qui dentro, una volta per tutte le schermate.
    // La riga è `mainAxisSize.min`, quindi in una Column senza
    // `crossAxisAlignment` finiva CENTRATA: succedeva in Club e Account
    // (correzioni 1.11). Il CSS la vuole a left 14/20, come in tutte le altre.
    // L'area di tocco resta sulla riga, non su tutta la larghezza.
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap ?? () => NavigatorService.goBack(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: padding ??
              EdgeInsets.fromLTRB(
                  R.sp(_leftDesign), R.sp(12), R.sp(12), R.sp(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                ImageConstant.imgArrowLeft,
                width: R.sp(_arrowSize),
                height: R.sp(_arrowSize),
              ),
              SizedBox(width: R.sp(_gap)),
              Text(label, style: OnlistTextStyles.title32Light),
            ],
          ),
        ),
      ),
    );
  }
}
