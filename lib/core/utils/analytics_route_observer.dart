import 'package:flutter/widgets.dart';

import '../../routes/app_routes.dart';
import '../services/analytics_service.dart';

/// Registra quale schermata è visibile guardando il Navigator, invece di
/// affidarsi a `initState`/`dispose` delle singole schermate.
///
/// Perché: una schermata coperta da un dettaglio NON viene smontata, e le tre
/// tab dello shell (Ordini, Home, Carrello) vengono montate tutte insieme
/// all'avvio. Con il vecchio mixin ogni avvio registrava `screen_orders_list`,
/// `screen_home` e `screen_cart` insieme, i cambi tab non lasciavano traccia e
/// il tempo sulla Home includeva quello passato nei dettagli aperti sopra.
///
/// Qui invece:
///  - push  → la nuova rotta diventa la schermata visibile;
///  - pop   → torna visibile quella sotto (`ritorno: true`);
///  - le rotte che non sono pagine (dialog, bottom sheet) non contano.
///
/// Ne servono due istanze: una sul Navigator radice (`main.dart`) e una su
/// quello annidato di `RootShell` (`annidato: true`). I cambi tab non passano
/// dal Navigator: li registra `RootShell.switchToTab`.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver({this.annidato = false});

  /// Navigator dello shell: la sua prima rotta (le tab) compare insieme allo
  /// shell stesso, che l'observer radice ha già registrato come `home`.
  final bool annidato;

  /// Nome della rotta che ospita le tab dentro lo shell.
  static const String rottaTabShell = 'shell_home';

  /// Nomi storici delle schermate (quelli che il foglio già conosce), per
  /// rotta. Le rotte assenti prendono il nome dalla rotta stessa:
  /// `/tavolo_detail_screen` → `tavolo_detail`.
  static const Map<String, String> _nomiPerRotta = {
    AppRoutes.splashScreen: 'splash',
    AppRoutes.authenticationScreen: 'authentication',
    AppRoutes.signUpScreen: 'sign_up',
    AppRoutes.locationPermissionScreen: 'location_permission',
    AppRoutes.locationManualScreen: 'location_manual',
    AppRoutes.clubDetailScreen: 'club_detail',
    AppRoutes.bookingScreen: 'booking_selection',
    AppRoutes.nearbyClubsScreen: 'search_nearby',
    AppRoutes.profileScreen: 'profile',
    AppRoutes.notificationsScreen: 'notifications',
    AppRoutes.cartScreen: 'cart',
    AppRoutes.ordersScreen: 'orders_list',
  };

  /// Nome della schermata mostrata da [rotta], `null` se non si sa.
  static String? nomeSchermata(String? rotta) {
    if (rotta == null) return null;
    if (rotta == rottaTabShell) {
      return AnalyticsService.nomeTabAttiva?.call() ?? 'home';
    }
    if (rotta == AppRoutes.homeScreen) {
      // La rotta radice dello shell: si vede la tab attiva, o il dettaglio
      // aperto sopra di essa nel Navigator annidato.
      final inCima = AnalyticsService.rottaInCimaShell?.call();
      if (inCima == null ||
          inCima == rottaTabShell ||
          inCima == AppRoutes.homeScreen) {
        return AnalyticsService.nomeTabAttiva?.call() ?? 'home';
      }
      return nomeSchermata(inCima);
    }
    final nome = _nomiPerRotta[rotta] ??
        rotta.replaceFirst(RegExp(r'^/'), '').replaceFirst(RegExp(r'_screen$'), '');
    return nome.isEmpty ? null : nome;
  }

  void _mostra(Route<dynamic>? route, {bool ritorno = false}) {
    if (route is! PageRoute) return;
    final nome = nomeSchermata(route.settings.name);
    if (nome == null) return;
    AnalyticsService.mostraSchermata(nome, ritorno: ritorno);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (annidato && previousRoute == null) return;
    _mostra(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Chiuso un dialog: la pagina sotto era già quella registrata.
    if (route is! PageRoute) return;
    _mostra(previousRoute, ritorno: true);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Conta solo se è stata tolta la rotta in cima. Con
    // pushNamedAndRemoveUntil la nuova rotta è già registrata da didPush.
    if (route is! PageRoute || previousRoute == null) return;
    if (!previousRoute.isCurrent) return;
    _mostra(previousRoute, ritorno: true);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null || !newRoute.isCurrent) return;
    _mostra(newRoute);
  }
}
