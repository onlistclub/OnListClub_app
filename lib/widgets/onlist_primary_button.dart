import 'package:flutter/material.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';

/// Bottone CTA full-width condiviso dal design Onlist Club.
///
/// Usato per: `AGGIUNGI AL CARRELLO`, `ORDINA IL TUO POSTO ORA`,
/// `TORNA NELLA HOME`, `CONTINUA L'ORDINE`. Tutti istanze dello stesso
/// template Figma: 370×43, gradiente `90deg #1800D2 19.48% → #120099 100%`,
/// border-radius 10, testo HelveticaNeue 24/28 w700 letter-spacing -0.07em.
///
/// La larghezza si adatta al parent (`double.infinity` di default). Per
/// rispettare la posizione Figma il caller usa un Padding orizzontale di
/// 11.5px sul container che lo contiene.
class OnlistPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool isLoading;

  const OnlistPrimaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.height = 43,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<OnlistPrimaryButton> createState() => _OnlistPrimaryButtonState();
}

class _OnlistPrimaryButtonState extends State<OnlistPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.96)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => _ctrl.forward(),
      onTapUp: disabled
          ? null
          : (_) {
              _ctrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: disabled ? null : () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: OnlistColors.primaryCTA,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: OnlistColors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Opacity(
                  opacity: disabled ? 0.5 : 1.0,
                  child: Text(
                    widget.label,
                    style: OnlistTextStyles.button24Bold,
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }
}
