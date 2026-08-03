import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';
import '../theme/onlist_colors.dart';
import '../theme/onlist_text_styles.dart';

/// Stili proposti per il banner "Club aggiunto ai preferiti".
///
/// Documento correzioni 1.1, punto 4: *"Non è impressionante quella scritta
/// «Club aggiunto ai preferiti» e l'animazione stessa, da modificare o mettere
/// un banner più figo"*. Qui ci sono tre proposte fra cui scegliere: cambia
/// [FavoriteBanner.stileScelto] e riprova, il resto del codice non si tocca.
///
/// Tutte e tre usano SOLO `Transform` + `Opacity` (nessun layout animato) e
/// stanno dentro un `RepaintBoundary`: a 60fps anche su un S7.
enum FavoriteBannerStyle {
  /// **Pill** — il banner di oggi, rifinito: gradiente brand invece del blu
  /// piatto, bordo chiaro 1px, alone esterno, icona segnalibro davanti al
  /// testo. Entra dall'alto con un rimbalzo (`easeOutBack`).
  ///
  /// La più conservativa: stessa forma di adesso, solo fatta meglio.
  pill,

  /// **Shine** — la stessa pill, con una passata di luce che l'attraversa una
  /// volta sola all'ingresso. È l'effetto "figo" a costo quasi zero: una banda
  /// bianca trasparente che trasla, niente blur né shader pesanti.
  shine,

  /// **Dal segnalibro** — il banner nasce piccolo dalla parte del segnalibro
  /// (basso-destra) e vola al suo posto ingrandendosi. È quello che lega di
  /// più l'animazione al gesto appena fatto dall'utente.
  fromBookmark,
}

/// Banner di conferma "Club aggiunto ai preferiti".
///
/// Si pilota da solo: gli passi [visible] e lui entra/esce. Non serve più un
/// `AnimationController` nella schermata.
class FavoriteBanner extends StatefulWidget {
  const FavoriteBanner({
    super.key,
    required this.visible,
    this.style = stileScelto,
    this.text = 'Club aggiunto ai preferiti',
    this.originDesign = const Offset(112, 150),
  });

  /// **Lo stile in uso nell'app.** Cambia QUESTA riga per provare le altre due
  /// proposte: `FavoriteBannerStyle.pill` / `.shine` / `.fromBookmark`.
  static const FavoriteBannerStyle stileScelto = FavoriteBannerStyle.shine;

  /// True mentre il banner deve stare a schermo.
  final bool visible;

  final FavoriteBannerStyle style;
  final String text;

  /// Solo per [FavoriteBannerStyle.fromBookmark]: da dove parte il banner,
  /// in px di design rispetto alla sua posizione finale. Di default punta
  /// verso il segnalibro (in basso a destra). Tenuto piccolo di proposito:
  /// lo `Stack` dell'hero clippa, e un punto di partenza fuori dall'immagine
  /// renderebbe invisibile metà animazione.
  final Offset originDesign;

  /// Quanto scende dall'alto negli stili [pill] e [shine], in px di design.
  static const double _cadutaDesign = 44;

  @override
  State<FavoriteBanner> createState() => _FavoriteBannerState();
}

class _FavoriteBannerState extends State<FavoriteBanner>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 240),
    value: widget.visible ? 1 : 0,
  );

  /// Passata di luce dello stile [FavoriteBannerStyle.shine].
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  /// Curva "elastica" per gli spostamenti: sfora oltre 1 (rimbalzo).
  late final Animation<double> _t = CurvedAnimation(
    parent: _in,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  /// L'opacità ha una curva sua: `easeOutBack` esce da 0..1 e farebbe
  /// scattare l'assert di [Opacity].
  late final Animation<double> _fade = CurvedAnimation(
    parent: _in,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  @override
  void didUpdateWidget(covariant FavoriteBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _in.forward(from: 0);
      if (widget.style == FavoriteBannerStyle.shine) _sweep.forward(from: 0);
    } else {
      _in.reverse();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _in,
        // `child` è costruito una volta sola: l'animazione muove soltanto
        // Transform/Opacity attorno a un sottoalbero già pronto.
        child: _contenuto(),
        builder: (_, child) {
          final double opacity = _fade.value.clamp(0.0, 1.0);
          // A riposo e invisibile: niente widget, niente paint, niente tap.
          if (opacity == 0 && !_in.isAnimating) return const SizedBox.shrink();

          final double t = _t.value;
          Widget w = Opacity(opacity: opacity, child: child);

          if (widget.style == FavoriteBannerStyle.fromBookmark) {
            w = Transform.translate(
              offset: Offset(
                R.sp(widget.originDesign.dx) * (1 - t),
                R.sp(widget.originDesign.dy) * (1 - t),
              ),
              child: Transform.scale(
                scale: 0.35 + 0.65 * t,
                // Cresce verso sinistra, come se uscisse dal segnalibro.
                alignment: Alignment.centerRight,
                child: w,
              ),
            );
          } else {
            w = Transform.translate(
              offset: Offset(0, -R.sp(FavoriteBanner._cadutaDesign) * (1 - t)),
              child: Transform.scale(scale: 0.92 + 0.08 * t, child: w),
            );
          }
          return w;
        },
      ),
    );
  }

  // ── La pill vera e propria (identica nei tre stili) ────────────────────────
  Widget _contenuto() {
    final BorderRadius raggio = BorderRadius.circular(R.sp(100));

    return Center(
      child: Container(
        padding: EdgeInsets.fromLTRB(R.sp(13), R.sp(7), R.sp(15), R.sp(7)),
        decoration: BoxDecoration(
          // Gradiente brand ufficiale (#1E00FF accento → #1900D8 brand) al
          // posto del blu piatto: gli dà volume senza uscire dalla palette.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [OnlistColors.blueElectric, OnlistColors.bluePrimary],
          ),
          border: Border.all(
            color: OnlistColors.white.withValues(alpha: 0.28),
            width: R.sp(1),
          ),
          borderRadius: raggio,
          boxShadow: [
            BoxShadow(
              color: OnlistColors.blueElectric.withValues(alpha: 0.45),
              blurRadius: R.sp(18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: raggio,
          child: Stack(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TODO(design): sostituire con l'SVG ufficiale del
                  // segnalibro quando arriva (stessa icona del titolo club).
                  Icon(
                    Icons.bookmark_rounded,
                    size: R.sp(15),
                    color: OnlistColors.white,
                  ),
                  SizedBox(width: R.sp(6)),
                  Text(
                    widget.text,
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(13),
                      // Il bundle non ha una faccia 600: il 600 cadeva sul 700.
                      fontWeight: FontWeight.w700,
                      color: OnlistColors.white,
                    ),
                  ),
                ],
              ),
              if (widget.style == FavoriteBannerStyle.shine)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sweep,
                      builder: (_, __) => _bandaDiLuce(_sweep.value),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banda bianca trasparente che attraversa la pill da sinistra a destra.
  /// È un semplice gradiente che trasla: nessun blur, nessuno shader.
  Widget _bandaDiLuce(double t) {
    if (t == 0 || t == 1) return const SizedBox.shrink();
    final double c = -1.6 + 3.2 * t; // centro banda, in unità Alignment
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(c - 0.45, -0.3),
          end: Alignment(c + 0.45, 0.3),
          colors: const [
            Color(0x00FFFFFF),
            Color(0x59FFFFFF), // bianco 35%
            Color(0x00FFFFFF),
          ],
        ),
      ),
    );
  }
}
