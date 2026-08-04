/// Sistema unico di transizioni di pagina dell'app.
///
/// Tutte le rotte passano da qui (vedi `AppRoutes.onGenerateRoute`) così che il
/// movimento abbia un'unica "personalità" coerente in tutta l'app, invece delle
/// transizioni di default della piattaforma.
///
/// Vincoli performance (device datati tipo Samsung S7):
/// - si anima SOLO con `Transform` (slide/scale) e `Opacity` (fade), mai layout;
/// - durate brevi (240–300ms) e curve naturali (`easeOutCubic`);
/// - per limitare le `saveLayer`, la pagina sottostante in shared-axis viene solo
///   traslata (niente fade), non si pagano due livelli di opacità a schermo intero.
///
/// Gestisce anche lo swipe-back (trascinamento dal bordo sinistro verso destra),
/// vedi `AppPageRoute` in fondo al file.
library;

import 'dart:math' show max, min;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Frazione di larghezza schermo di cui arretra la pagina COPERTA mentre quella
/// nuova le scorre sopra (e di cui rientra, più lenta del dito, durante lo
/// swipe-back). È il parallax in stile iOS: dà la sensazione di due fogli
/// sovrapposti invece di uno che scivola sul vuoto.
///
/// Lo stesso valore vale sia in push sia durante il gesto: se differissero, la
/// pagina sotto salterebbe di posizione nell'istante in cui il dito tocca.
const double kPageParallaxFraction = 0.25;

/// Opacità massima del velo sulla pagina coperta (a copertura completa).
/// Si schiarisce man mano che la pagina riemerge sotto il dito.
const double _kScrimOpacity = 0.25;

/// Larghezza della striscia d'ombra sul bordo d'attacco della pagina in primo
/// piano. È un gradiente stretto, non una `BoxShadow` a schermo intero: costa
/// una sola fascia di pixel invece di un blur su tutta la pagina (S7).
const double _kEdgeShadowWidth = 14.0;

const BoxDecoration _kEdgeShadow = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0x00000000), Color(0x40000000)],
  ),
);

/// Tipi di transizione disponibili.
enum AppTransition {
  /// Slide orizzontale corto + fade dell'entrante. Per avanzamento gerarchico
  /// (home → club → booking → cart).
  sharedAxis,

  /// Dissolvenza con micro-scala. Per cambi a pari livello e ingressi
  /// "atmosferici" (splash → auth/home, schermata di successo).
  fade,

  /// Pop-up che "arriva": parte piccolo e trasparente e si apre con un
  /// rimbalzo, come una finestra che scatta in primo piano. Per il pop-up
  /// info serata, che è una rotta ma deve sembrare un pannello sovrapposto.
  popup,
}

/// Costruisce la `PageRoute` per una rotta, applicando la transizione scelta.
///
/// `enableBackGesture` abilita lo swipe-back su questa schermata: va acceso solo
/// dove tornare indietro ha senso (vedi `AppRoutes.onGenerateRoute`).
Route<dynamic> buildAppRoute(
  RouteSettings settings,
  WidgetBuilder builder,
  AppTransition transition, {
  bool enableBackGesture = false,
}) {
  switch (transition) {
    case AppTransition.fade:
      return AppPageRoute<dynamic>(
        settings: settings,
        enableBackGesture: enableBackGesture,
        transition: AppTransition.fade,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, _, __) => builder(context),
        transitionsBuilder: _fadeThrough,
      );
    case AppTransition.popup:
      return AppPageRoute<dynamic>(
        settings: settings,
        enableBackGesture: enableBackGesture,
        transition: AppTransition.popup,
        // Più lunga dell'ingresso normale: il rimbalzo ha bisogno di spazio
        // per leggersi. In uscita invece va via svelto, senza rimbalzo.
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, _, __) => builder(context),
        transitionsBuilder: _popup,
      );
    case AppTransition.sharedAxis:
      return AppPageRoute<dynamic>(
        settings: settings,
        enableBackGesture: enableBackGesture,
        transition: AppTransition.sharedAxis,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, _, __) => builder(context),
        transitionsBuilder: _sharedAxisHorizontal,
      );
  }
}

// ── Pop-up ────────────────────────────────────────────────────────────────────
// Il pannello arriva da dietro: parte al 90%, si apre superando di un soffio
// la sua misura e si assesta (easeOutBack). L'opacità sale prima della scala,
// così il rimbalzo si vede già a pannello leggibile invece che su un fantasma.
//
// Solo Transform e Opacity, nessun layout: 60fps anche su S7. In chiusura
// niente rimbalzo — tornare indietro deve essere immediato, non giocoso.
Widget _popup(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final scala = Tween<double>(begin: 0.90, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ),
  );
  // L'opacità ha una curva sua: `easeOutBack` esce da 0..1 e farebbe scattare
  // l'assert di FadeTransition.
  final opacita = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    reverseCurve: Curves.easeIn,
  );

  return FadeTransition(
    opacity: opacita,
    child: ScaleTransition(scale: scala, child: child),
  );
}

// ── Shared-axis orizzontale ───────────────────────────────────────────────────
// Entrante: slide da destra (offset corto) + fade in.
// Uscente (coperta): solo slide a sinistra (offset più corto), nessun fade →
// una sola saveLayer a schermo intero invece di due.
Widget _sharedAxisHorizontal(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  const curve = Curves.easeOutCubic;

  final fadeIn = CurvedAnimation(parent: animation, curve: curve);
  final slideIn = Tween<Offset>(
    begin: const Offset(0.06, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: curve));

  final slideOut = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.04, 0),
  ).animate(CurvedAnimation(parent: secondaryAnimation, curve: curve));

  return SlideTransition(
    position: slideOut,
    child: FadeTransition(
      opacity: fadeIn,
      child: SlideTransition(position: slideIn, child: child),
    ),
  );
}

// ── Fade-through ──────────────────────────────────────────────────────────────
// Entrante: fade in + micro-scala 0.98 → 1 (sensazione "premium" di profondità).
// Uscente: fade out. Curve easeOutCubic, nessun movimento orizzontale.
Widget _fadeThrough(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  const curve = Curves.easeOutCubic;

  final fadeIn = CurvedAnimation(parent: animation, curve: curve);
  final scaleIn = Tween<double>(begin: 0.98, end: 1.0)
      .animate(CurvedAnimation(parent: animation, curve: curve));
  final fadeOut = Tween<double>(begin: 1.0, end: 0.0)
      .animate(CurvedAnimation(parent: secondaryAnimation, curve: curve));

  return FadeTransition(
    opacity: fadeOut,
    child: FadeTransition(
      opacity: fadeIn,
      child: ScaleTransition(scale: scaleIn, child: child),
    ),
  );
}

/// Applica il solo parallax da "pagina coperta" alle rotte che NON sono
/// [AppPageRoute] e quindi non passano dal calcolo di `buildTransitions`: in
/// pratica il contenitore dei tab dello shell, che sta sempre in fondo allo
/// stack ed è la pagina che si vede sotto durante quasi tutti gli swipe-back.
/// Senza questo, il parallax mancherebbe proprio nel caso più comune.
///
/// Velo e ombra li disegna già la pagina in primo piano, qui non servono.
class CoveredPageParallax extends StatelessWidget {
  const CoveredPageParallax({
    Key? key,
    required this.secondaryAnimation,
    required this.child,
  }) : super(key: key);

  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Risolto una volta per rebuild, non a ogni frame: dentro il builder si
    // legge solo il campo.
    final NavigatorState? nav = Navigator.maybeOf(context);
    return AnimatedBuilder(
      animation: secondaryAnimation,
      child: child,
      builder: (context, c) {
        final double sv = secondaryAnimation.value.clamp(0.0, 1.0);
        // Stessa regola di AppPageRoute: lineare sotto il dito, curva altrove.
        final double csv = (nav?.userGestureInProgress ?? false)
            ? sv
            : Curves.easeOutCubic.transform(sv);
        return FractionalTranslation(
          translation: Offset(-kPageParallaxFraction * csv, 0),
          child: c,
        );
      },
    );
  }
}

// ── Swipe-back ────────────────────────────────────────────────────────────────
// Il gesto pilota all'indietro il controller della rotta col dito. Il rendering
// del drag è gestito da `AppPageRoute.buildTransitions`: durante il gesto la
// pagina fa uno slide orizzontale coerente su OGNI schermata (anche i fade come
// club_detail, che altrimenti svanirebbero in opacità invece di seguire il dito)
// senza `saveLayer` a schermo intero, così resta fluido su device datati.

/// Larghezza della zona sensibile sul bordo sinistro (come iOS). Leggermente più
/// larga dei 20px canonici per rendere l'innesco più affidabile col pollice.
const double _kBackGestureWidth = 24.0;

/// Velocità (in schermate al secondo) oltre la quale il drag è un "fling".
const double _kMinFlingVelocity = 1.0;

/// Tempi massimi per riportare la pagina a posto / completarne l'uscita quando
/// l'utente lascia il dito a metà strada.
const int _kMaxDroppedSwipePageForwardAnimationTime = 800;
const int _kMaxPageBackAnimationTime = 300;

/// `PageRoute` dell'app: applica la transizione scelta e, se `enableBackGesture`
/// è true, permette di tornare indietro trascinando dal bordo sinistro.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required super.settings,
    required super.pageBuilder,
    required RouteTransitionsBuilder super.transitionsBuilder,
    required super.transitionDuration,
    required super.reverseTransitionDuration,
    required this.enableBackGesture,
    required this.transition,
  });

  /// Se il gesto è ammesso su questa schermata (decisione di navigazione, presa
  /// in `AppRoutes`). Non basta da solo: vedi `_isBackGestureEnabled`.
  final bool enableBackGesture;

  /// Tipo di transizione della rotta. Serve a `buildTransitions` per riprodurre
  /// fade / shared-axis nella struttura unificata usata dalle rotte con
  /// swipe-back (vedi sotto).
  final AppTransition transition;

  /// Vero solo se il gesto è ammesso *e* lo stato corrente lo consente: c'è una
  /// schermata sotto, nessuno ha bloccato il pop (`PopScope`), non ci sono
  /// animazioni o altri gesti in corso.
  bool get _isBackGestureEnabled {
    if (!enableBackGesture) return false;
    if (isFirst) return false;
    if (willHandlePopInternally) return false;
    if (popDisposition == RoutePopDisposition.doNotPop) return false;
    if (fullscreenDialog) return false;
    if (animation?.status != AnimationStatus.completed) return false;
    if (secondaryAnimation?.status != AnimationStatus.dismissed) return false;
    if (navigator?.userGestureInProgress ?? true) return false;
    return true;
  }

  _BackGestureController<T> _startBackGesture() {
    return _BackGestureController<T>(
      navigator: navigator!,
      controller: controller!,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Il detector sta DENTRO la transizione: si muove insieme alla pagina e non
    // intercetta nulla quando la rotta è coperta da un'altra.
    final Widget page = enableBackGesture
        ? _BackGestureDetector<T>(
            enabledCallback: () => _isBackGestureEnabled,
            onStartGesture: _startBackGesture,
            child: child,
          )
        : child;

    // Rotte senza swipe-back: transizione standard invariata.
    if (!enableBackGesture) {
      return super.buildTransitions(context, animation, secondaryAnimation, page);
    }

    // Rotte con swipe-back: la pagina passa SEMPRE per la stessa struttura
    // (scrim → Opacity → slide → scale → ombra), ricalcolata per frame variando
    // solo i valori, mai i tipi di widget. Così l'elemento pagina resta stabile
    // (niente reparenting/flash quando parte o finisce il gesto).
    //
    // - Durante un back-gesture dell'utente: slide orizzontale puro che segue il
    //   dito, opacità piena e scala 1 → nessuna `saveLayer` a schermo intero,
    //   quindi resta fluido anche su S7 (prima club_detail "scrubbava" un fade).
    // - Fuori dal gesto: riproduce fedelmente fade o shared-axis (push / back a
    //   pulsante), inclusa l'uscita quando la rotta viene coperta da un'altra
    //   (`secondaryAnimation`).
    //
    // In più, in entrambi i casi, i tre ingredienti che danno profondità al
    // gesto: parallax della pagina coperta ([kPageParallaxFraction]), velo che
    // la scurisce e ombra sul bordo d'attacco di quella in primo piano.
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[animation, secondaryAnimation]),
      child: page,
      builder: (context, c) {
        final bool dragging = navigator?.userGestureInProgress ?? false;
        final double v = animation.value.clamp(0.0, 1.0);
        final double sv = secondaryAnimation.value.clamp(0.0, 1.0);

        // Durante il gesto il movimento è LINEARE: la pagina in primo piano
        // segue il dito 1:1, quindi anche il parallax e il velo devono seguirlo
        // linearmente, o si sfaserebbero rispetto al dito. Fuori dal gesto
        // (push / back a pulsante) passano entrambi dalla curva.
        final double cv = dragging ? v : Curves.easeOutCubic.transform(v);
        final double csv = dragging ? sv : Curves.easeOutCubic.transform(sv);

        double opacity;
        double dx;
        double scale;

        if (dragging && v < 1.0) {
          // È questa la pagina trascinata: segue il dito, senza fade né scala.
          opacity = 1.0;
          dx = 1.0 - v; // frazione di larghezza
          scale = 1.0;
        } else {
          switch (transition) {
            case AppTransition.fade:
              opacity = (cv * (1.0 - csv)).clamp(0.0, 1.0);
              dx = 0.0;
              scale = 0.98 + 0.02 * cv;
            case AppTransition.sharedAxis:
              opacity = cv;
              dx = 0.06 * (1.0 - cv);
              scale = 1.0;
            case AppTransition.popup:
              // Il pannello arriva da dietro: opacità piena già a metà corsa,
              // così il rimbalzo si vede su un pop-up leggibile e non su un
              // fantasma. La scala passa da easeOutBack, che sfora l'1 e
              // rientra — è quello a dare lo "scatto" in primo piano.
              opacity = (cv / 0.55).clamp(0.0, 1.0);
              dx = 0.0;
              scale = 0.90 + 0.10 * Curves.easeOutBack.transform(v);
          }
        }

        // Parallax: quando questa pagina viene coperta arretra di una frazione
        // di schermo. In swipe-back rientra da sinistra più lenta del dito.
        dx -= kPageParallaxFraction * csv;

        // Velo sulla pagina sottostante: sta FUORI dalla traslazione (non si
        // muove con la pagina) e sotto di essa nello stack, quindi vela solo
        // ciò che sta più in basso. `ColoredBox` con alpha 0 non dipinge.
        final double scrim = _kScrimOpacity * cv;

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: scrim)),
            ),
            Opacity(
              opacity: opacity,
              child: FractionalTranslation(
                translation: Offset(dx, 0),
                child: Transform.scale(
                  scale: scale,
                  // L'ombra sta DENTRO la traslazione: viaggia col bordo della
                  // pagina. A riposo finisce fuori schermo a sinistra, quindi
                  // si vede solo mentre la pagina è scostata. `Clip.none` le
                  // permette di stare fuori dai limiti dello stack.
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      c!,
                      const Positioned(
                        top: 0,
                        bottom: 0,
                        left: -_kEdgeShadowWidth,
                        width: _kEdgeShadowWidth,
                        child: IgnorePointer(
                          child: DecoratedBox(decoration: _kEdgeShadow),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Traduce il drag in movimento del controller della rotta e decide, al
/// rilascio, se completare il pop o rimettere la pagina a posto.
class _BackGestureController<T> {
  _BackGestureController({required this.navigator, required this.controller}) {
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;

  /// `delta` è una frazione di larghezza schermo: trascinando verso destra il
  /// controller torna verso 0, cioè verso la schermata sottostante.
  void dragUpdate(double delta) => controller.value -= delta;

  /// `velocity` in schermate al secondo.
  void dragEnd(double velocity) {
    const Curve curve = Curves.fastLinearToSlowEaseIn;

    // Fling deciso → vince la direzione del dito. Altrimenti decide la soglia
    // di metà schermo.
    final bool animateForward = velocity.abs() >= _kMinFlingVelocity
        ? velocity <= 0
        : controller.value > 0.5;

    if (animateForward) {
      // Si resta sulla schermata: la si riporta a posto.
      final int duration = min(
        lerpDouble(_kMaxDroppedSwipePageForwardAnimationTime, 0, controller.value)!
            .floor(),
        _kMaxPageBackAnimationTime,
      );
      controller.animateTo(
        1.0,
        duration: Duration(milliseconds: duration),
        curve: curve,
      );
    } else {
      // Pop: il Navigator riprende in mano l'animazione dal punto in cui il
      // dito l'ha lasciata, quindi niente salto visivo.
      navigator.pop();
      if (controller.isAnimating) {
        final int duration = lerpDouble(
          0,
          _kMaxDroppedSwipePageForwardAnimationTime,
          controller.value,
        )!
            .floor();
        controller.animateBack(
          0.0,
          duration: Duration(milliseconds: duration),
          curve: curve,
        );
      }
    }

    if (controller.isAnimating) {
      late final AnimationStatusListener listener;
      listener = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(listener);
      };
      controller.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

/// Zona sensibile sul bordo sinistro. È un `Stack` senza layout costoso: la
/// pagina resta il primo figlio e sopra c'è solo una striscia trasparente che
/// inoltra i pointer al recognizer.
class _BackGestureDetector<T> extends StatefulWidget {
  const _BackGestureDetector({
    required this.enabledCallback,
    required this.onStartGesture,
    required this.child,
  });

  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_BackGestureController<T>> onStartGesture;
  final Widget child;

  @override
  State<_BackGestureDetector<T>> createState() => _BackGestureDetectorState<T>();
}

class _BackGestureDetectorState<T> extends State<_BackGestureDetector<T>> {
  _BackGestureController<T>? _gestureController;
  late final HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    // Se la rotta viene smontata mentre il dito è ancora giù, il Navigator
    // resterebbe convinto che un gesto sia in corso.
    if (_gestureController != null) {
      final NavigatorState navigator = _gestureController!.navigator;
      WidgetsBinding.instance
          .scheduleFrameCallback((_) => navigator.didStopUserGesture());
      _gestureController = null;
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _gestureController = widget.onStartGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // Difesa: se la size non è ancora nota (o è 0), o l'update arriva dopo lo
    // smontaggio, evita l'eccezione che troncherebbe il gesto a metà.
    final double? width = context.size?.width;
    if (width == null || width == 0) return;
    _gestureController?.dragUpdate(
      _toLogical((details.primaryDelta ?? 0) / width),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    final double width = context.size?.width ?? 0;
    _gestureController?.dragEnd(
      width == 0
          ? 0.0
          : _toLogical(details.velocity.pixelsPerSecond.dx / width),
    );
    _gestureController = null;
  }

  void _handleDragCancel() {
    // dragEnd(0) rimette la pagina a posto senza poppare.
    _gestureController?.dragEnd(0.0);
    _gestureController = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) _recognizer.addPointer(event);
  }

  double _toLogical(double value) {
    return Directionality.of(context) == TextDirection.rtl ? -value : value;
  }

  @override
  Widget build(BuildContext context) {
    // Almeno quanto l'inset di sistema, così la striscia non finisce sotto il
    // notch/gesture bar in landscape.
    final double dragAreaWidth = max(
      _kBackGestureWidth,
      MediaQuery.paddingOf(context).left,
    );

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: dragAreaWidth,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}
