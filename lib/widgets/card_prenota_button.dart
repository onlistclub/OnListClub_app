import 'package:flutter/material.dart';

import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';

/// Bottone PRENOTA delle card club/serata (CSS NUOVO 16/09, Rectangle
/// 298/302): 67×26 r7, gradiente bianco→blu al 20%, ombra 0 2 4.3.
///
/// Misure in px design: va usato dentro una card già scalata (FittedBox),
/// quindi niente R.sp. Con [onTap] null resta visibile ma non risponde
/// (serata esaurita).
class CardPrenotaButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;

  const CardPrenotaButton({super.key, this.onTap, this.label = 'PRENOTA'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 67,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: OnlistColors.cardPrenotaButton,
          borderRadius: BorderRadius.circular(7),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              offset: Offset(0, 2),
              blurRadius: 4.3,
            ),
          ],
        ),
        // Nel CSS la scritta è un vettore 55.87×9.7: altezza maiuscole 9.7
        // → corpo ~13.5 in Helvetica bold.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: OnlistTextStyles.hn(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
              letterSpacing: -0.08 * 13.5,
            ),
          ),
        ),
      ),
    );
  }
}
