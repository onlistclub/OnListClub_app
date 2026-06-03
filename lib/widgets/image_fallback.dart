import 'package:flutter/material.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';

/// Fallback grafico UNICO per quando un'immagine reale (foto del locale o
/// locandina dell'evento) manca o non si carica.
///
/// Coerente col design system: fondo `blueDeep`, icona discreta e testo
/// "Nessuna immagine disponibile". Non è MAI una foto finta che possa essere
/// scambiata per un dato reale. Si adatta allo spazio: nei riquadri piccoli
/// (thumbnail) mostra solo l'icona, in quelli grandi anche il testo.
class ImageFallback extends StatelessWidget {
  const ImageFallback({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: OnlistColors.blueDeep),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 120 || constraints.maxHeight < 70;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hide_image_outlined,
                  color: Colors.white.withValues(alpha: 0.45),
                  size: compact ? 22 : 30,
                ),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Nessuna immagine disponibile',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: OnlistTextStyles.hn(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
