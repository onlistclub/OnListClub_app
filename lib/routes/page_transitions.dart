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

/// Tipi di transizione disponibili.
enum AppTransition {
  /// Slide orizzontale corto + fade dell'entrante. Per avanzamento gerarchico
  /// (home → club → booking → cart).
  sharedAxis,

  /// Dissolvenza con micro-scala. Per cambi a pari livello e ingressi
  /// "atmosferici" (splash → auth/home, schermata di successo).
  fade,
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
    // (Opacity → slide → scale), ricalcolata per frame variando solo i valori,
    // mai i tipi di widget. Così l'elemento pagina resta stabile (niente
    // reparenting/flash quando parte o finisce il gesto).
    //
    // - Durante un back-gesture dell'utente: slide orizzontale puro che segue il
    //   dito, opacità piena e scala 1 → nessuna `saveLayer` a schermo intero,
    //   quindi resta fluido anche su S7 (prima club_detail "scrubbava" un fade).
    // - Fuori dal gesto: riproduce fedelmente fade o shared-axis (push / back a
    //   pulsante), inclusa l'uscita quando la rotta viene coperta da un'altra
    //   (`secondaryAnimation`).
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[animation, secondaryAnimation]),
      child: page,
      builder: (context, c) {
        final bool dragging = navigator?.userGestureInProgress ?? false;
        final double v = animation.value;

        double opacity;
        double dx;
        double scale;

        if (dragging) {
          opacity = 1.0;
          dx = 1.0 - v; // frazione di larghezza: la pagina segue il dito
          scale = 1.0;
        } else {
          final double cv = Curves.easeOutCubic.transform(v.clamp(0.0, 1.0));
          final double csv = Curves.easeOutCubic
              .transform(secondaryAnimation.value.clamp(0.0, 1.0));
          switch (transition) {
            case AppTransition.fade:
              opacity = (cv * (1.0 - csv)).clamp(0.0, 1.0);
              dx = 0.0;
              scale = 0.98 + 0.02 * cv;
            case AppTransition.sharedAxis:
              opacity = cv;
              dx = 0.06 * (1.0 - cv) - 0.04 * csv;
              scale = 1.0;
          }
        }

        return Opacity(
          opacity: opacity,
          child: FractionalTranslation(
            translation: Offset(dx, 0),
            child: Transform.scale(scale: scale, child: c),
          ),
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
