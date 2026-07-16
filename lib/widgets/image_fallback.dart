import 'package:flutter/material.dart';
import '../core/constants/image_constant.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';

/// Fallback UNICO per quando un'immagine reale (foto del locale o locandina
/// dell'evento) manca o non si carica.
///
/// Ha due rese, scelte da [seed]:
///
/// - **Con [seed]** (l'id del locale/evento): mostra una delle immagini di
///   stock in `assets/images/stock_club_<n>.jpg`, scelta in modo deterministico.
///   Serve perché gli URL remoti del seed non sono garantiti nel tempo — 4 dei
///   19 ID Unsplash usati sono già stati rimossi a monte, lasciando dei buchi
///   in griglia. L'asset locale non può 404-are.
/// - **Senza [seed]**: fondo `blueDeep`, icona discreta e "Nessuna immagine
///   disponibile". Da usare dove non c'è un id stabile a cui agganciarsi.
///
/// Nota: fino al 2026-07-16 questo widget non mostrava mai una foto, per non
/// spacciare uno stock per un dato reale. La regola aveva senso in astratto ma
/// non descriveva la realtà: nel DB *tutte* le foto di locali ed eventi sono
/// già stock del seed, nessuna è una foto vera del locale. Il fallback stock
/// non aggiunge quindi finzione — la toglie dal caso "buco visibile". Quando i
/// locali caricheranno foto reali, il compromesso va rivalutato: uno stock al
/// posto della foto vera di un club diventa fuorviante per chi prenota.
class ImageFallback extends StatelessWidget {
  const ImageFallback({Key? key, this.seed}) : super(key: key);

  /// Id stabile (locale o evento) da cui derivare quale stock mostrare. Se null
  /// o vuoto, si ricade sul fallback grafico "Nessuna immagine disponibile".
  final String? seed;

  /// Hash stabile fra run e piattaforme: `String.hashCode` in Dart non lo è, e
  /// un locale che cambia foto a ogni riavvio sembrerebbe un bug.
  static String _stockFor(String seed) {
    var h = 0;
    for (final unit in seed.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return ImageConstant.stockClub[h % ImageConstant.stockClub.length];
  }

  @override
  Widget build(BuildContext context) {
    final s = seed;
    if (s != null && s.isNotEmpty) {
      return Image.asset(
        _stockFor(s),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

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
