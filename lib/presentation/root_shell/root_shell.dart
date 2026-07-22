import 'package:flutter/material.dart';

import '../../core/services/navigator_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/shared_footer.dart';
import '../home_screen/home_screen.dart';
import '../orders_screen/orders_screen.dart';
import '../cart_screen/cart_screen.dart';

/// Shell persistente post-login.
///
/// Struttura:
/// ```
/// Scaffold
///  ├─ body: Navigator annidato (_navKey)
///  │     ├─ route iniziale  → IndexedStack[Ordini, Home, Carrello]  (i 3 tab,
///  │     │                     tenuti VIVI: cambiare tab non ricarica nulla)
///  │     └─ dettagli (club, booking, …) push sopra, con swipe verticale
///  └─ bottomNavigationBar: SharedFooter  (UNICA nell'app, fuori dalle route:
///                          resta fissa sia al cambio tab sia durante lo swipe)
/// ```
///
/// I dettagli vengono spinti sul Navigator annidato tramite [NavigatorService]
/// (che indirizza al navigator dello shell le rotte in [AppRoutes.shellRoutes]).
/// Poiché stanno nel `body`, sono sempre SOTTO la footer: la footer non viene
/// mai coinvolta dal `Transform` dello swipe.
class RootShell extends StatefulWidget {
  const RootShell({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const RootShell();

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  /// Nome della route "host dei tab" nel Navigator annidato.
  static const String _shellHomeRoute = 'shell_home';

  // Indici allineati alla SharedFooter: 0 = Ticket/Ordini, 1 = Home, 2 = Carrello.
  static const int _tabHome = 1;

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _tab = ValueNotifier<int>(_tabHome);

  // Costruiti UNA sola volta: l'IndexedStack li tiene tutti montati (stato
  // preservato tra i cambi tab). Non montano una footer propria: quella valida
  // è la [SharedFooter] globale dello shell.
  late final List<Widget> _tabs = [
    OrdersScreen.builder(context),
    HomeScreen.builder(context),
    CartScreen.builder(context),
  ];

  @override
  void initState() {
    super.initState();
    // Da ora le rotte di dettaglio ([AppRoutes.shellRoutes]) vengono spinte qui,
    // e le navigazioni verso le root del footer diventano cambi-tab.
    NavigatorService.shellNavigatorKey = _navKey;
    NavigatorService.switchTab = switchToTab;
  }

  @override
  void dispose() {
    if (NavigatorService.shellNavigatorKey == _navKey) {
      NavigatorService.shellNavigatorKey = null;
    }
    if (NavigatorService.switchTab == switchToTab) {
      NavigatorService.switchTab = null;
    }
    _tab.dispose();
    super.dispose();
  }

  void switchToTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    // Chiude eventuali dettagli aperti e torna alla radice della tab scelta.
    _navKey.currentState?.popUntil((r) => r.isFirst);
    _tab.value = index;
  }

  /// Host dei 3 tab, in ascolto di [_tab]: cambiare tab ricostruisce solo
  /// l'IndexedStack (i figli restano montati), non tocca la footer né le route.
  Route<dynamic> _shellHome(RouteSettings settings) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => ValueListenableBuilder<int>(
        valueListenable: _tab,
        builder: (_, index, __) => IndexedStack(index: index, children: _tabs),
      ),
    );
  }

  Route<dynamic>? _onGenerateShellRoute(RouteSettings settings) {
    if (settings.name == _shellHomeRoute) return _shellHome(settings);
    // I dettagli riusano il sistema unico di rotte/transizioni dell'app
    // (fade/shared-axis + swipe verticale gestiti da AppPageRoute).
    return AppRoutes.onGenerateRoute(settings);
  }

  @override
  Widget build(BuildContext context) {
    return RootShellScope(
      switchToTab: switchToTab,
      child: Scaffold(
        backgroundColor: Colors.black,
        // La footer flotta: i contenuti scorrono dietro la capsula.
        extendBody: true,
        body: Navigator(
          key: _navKey,
          onGenerateInitialRoutes: (navigator, initialRoute) =>
              <Route<dynamic>>[
            _shellHome(const RouteSettings(name: _shellHomeRoute)),
          ],
          onGenerateRoute: _onGenerateShellRoute,
        ),
        // Unica footer dell'app: fuori dalle route → fissa in ogni situazione.
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: _tab,
          builder: (_, index, __) => SharedFooter(
            currentIndex: index,
            onTabSelected: switchToTab,
          ),
        ),
      ),
    );
  }
}

/// Espone [switchToTab] ai discendenti dello shell (tab e dettagli), es. il
/// "Torna indietro" di Ordini che deve tornare alla Home come TAB invece di
/// renavigare/ricostruire. Se `RootShellScope.of(context)` è null la schermata
/// non è dentro lo shell e i chiamanti applicano il fallback legacy.
class RootShellScope extends InheritedWidget {
  const RootShellScope({
    Key? key,
    required this.switchToTab,
    required Widget child,
  }) : super(key: key, child: child);

  final void Function(int index) switchToTab;

  static RootShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RootShellScope>();

  @override
  bool updateShouldNotify(RootShellScope oldWidget) => false;
}
