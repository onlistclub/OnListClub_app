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
library;

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
Route<dynamic> buildAppRoute(
  RouteSettings settings,
  WidgetBuilder builder,
  AppTransition transition,
) {
  switch (transition) {
    case AppTransition.fade:
      return PageRouteBuilder(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, _, __) => builder(context),
        transitionsBuilder: _fadeThrough,
      );
    case AppTransition.sharedAxis:
      return PageRouteBuilder(
        settings: settings,
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
