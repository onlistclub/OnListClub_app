import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

/// Servizio di navigazione globale, indipendente da `BuildContext`.
///
/// Espone la `navigatorKey` del Navigator radice (agganciata da `MaterialApp`
/// in `main.dart`) e, quando lo shell post-login è montato, la
/// [shellNavigatorKey] del suo Navigator annidato.
///
/// Regola di instradamento:
/// - le rotte di DETTAGLIO ([AppRoutes.shellRoutes]) vanno sul Navigator
///   annidato dello shell, così restano SOTTO la footer fissa e la schermata
///   precedente resta viva (swipe verticale);
/// - tutto il resto (splash, auth, home/shell, reset di stack) va sul Navigator
///   radice.
// ignore_for_file: must_be_immutable
class NavigatorService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigator annidato dello shell persistente. Valorizzato da `RootShell`
  /// quando è montato, `null` prima del login o dopo il suo smontaggio.
  static GlobalKey<NavigatorState>? shellNavigatorKey;

  /// Cambio-tab dello shell, registrato da `RootShell`. `null` fuori dallo shell.
  static void Function(int index)? switchTab;

  /// Indice tab per le 3 rotte-root del footer (0=Ordini, 1=Home, 2=Carrello).
  /// Serve a tradurre un `pushNamed` verso una root in un CAMBIO TAB invece di
  /// un push (che monterebbe un doppione o coprirebbe con un secondo shell).
  static int? _tabIndexFor(String routeName) {
    if (routeName == AppRoutes.homeScreen) return 1;
    if (routeName == AppRoutes.ordersScreen) return 0;
    if (routeName == AppRoutes.cartScreen) return 2;
    return null;
  }

  /// Navigator a cui indirizzare `pushNamed(routeName)`: lo shell per le rotte
  /// di dettaglio (se montato), altrimenti il Navigator radice.
  static NavigatorState? _targetFor(String routeName) {
    final shell = shellNavigatorKey?.currentState;
    if (shell != null && AppRoutes.shellRoutes.contains(routeName)) {
      return shell;
    }
    return navigatorKey.currentState;
  }

  static Future<dynamic> pushNamed(
    String routeName, {
    dynamic arguments,
  }) async {
    // Dentro lo shell, navigare a una root del footer = cambio tab (stato
    // preservato). Il Carrello con `arguments` fa eccezione: è il flusso di
    // prenotazione (checkout), che deve essere spinto come dettaglio.
    if (switchTab != null && arguments == null) {
      final tab = _tabIndexFor(routeName);
      if (tab != null) {
        switchTab!(tab);
        return null;
      }
    }
    return _targetFor(routeName)?.pushNamed(routeName, arguments: arguments);
  }

  static void goBack({dynamic result}) {
    // Se c'è un dettaglio aperto nello shell, "indietro" lo chiude (Navigator
    // annidato); altrimenti pop sul Navigator radice.
    final shell = shellNavigatorKey?.currentState;
    if (shell != null && shell.canPop()) {
      shell.pop(result);
      return;
    }
    navigatorKey.currentState?.pop(result);
  }

  /// Reset dello stack: opera SEMPRE sul Navigator radice (es. login → home,
  /// logout → auth). Montando `homeScreen` (= RootShell) si riparte dallo shell.
  static Future<dynamic> pushNamedAndRemoveUntil(
    String routeName, {
    bool routePredicate = false,
    dynamic arguments,
  }) async {
    return navigatorKey.currentState?.pushNamedAndRemoveUntil(
        routeName, (route) => routePredicate,
        arguments: arguments);
  }

  static Future<dynamic> popAndPushNamed(
    String routeName, {
    dynamic arguments,
  }) async {
    return (_targetFor(routeName) ?? navigatorKey.currentState)
        ?.popAndPushNamed(routeName, arguments: arguments);
  }
}
