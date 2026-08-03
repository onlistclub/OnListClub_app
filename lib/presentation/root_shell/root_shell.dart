import 'package:flutter/material.dart';

import '../../core/services/navigator_service.dart';
import '../../core/services/pending_order_service.dart';
import '../../routes/app_routes.dart';
import '../../routes/page_transitions.dart';
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

class _RootShellState extends State<RootShell>
    with SingleTickerProviderStateMixin {
  /// Nome della route "host dei tab" nel Navigator annidato.
  static const String _shellHomeRoute = 'shell_home';

  // Indici allineati alla SharedFooter: 0 = Ticket/Ordini, 1 = Home, 2 = Carrello.
  static const int _tabHome = 1;

  static const int _tabCarrello = 2;

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _tab = ValueNotifier<int>(_tabHome);

  /// Icona da illuminare per via della ROTTA in cima, indipendentemente dal tab
  /// scelto. Null = comanda il tab.
  ///
  /// Serve perché aprire un dettaglio non cambia `_tab`: entrando in
  /// prenotazione dalla Home restava acceso il pallino Home, mentre l'utente è
  /// di fatto in fase d'acquisto. Il documento correzioni 1.1 (punto 10) chiede
  /// che lì si accenda il CARRELLO.
  final ValueNotifier<int?> _routeHighlight = ValueNotifier<int?>(null);

  /// Rotte che forzano un'icona diversa da quella del tab.
  static const Map<String, int> _highlightPerRotta = {
    AppRoutes.bookingScreen: _tabCarrello,
    AppRoutes.cartScreen: _tabCarrello,
  };

  late final _HighlightObserver _routeObserver =
      _HighlightObserver(onTop: _aggiornaHighlight);

  void _aggiornaHighlight(String? routeName) {
    _routeHighlight.value = _highlightPerRotta[routeName];
  }

  // Animazione del cambio tab: fade + micro-scala (stessa "personalità" della
  // transizione `fade` dell'app). Solo Opacity/Transform → niente layout.
  late final AnimationController _tabAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1.0, // primo build già visibile
  );
  late final Animation<double> _tabFade =
      CurvedAnimation(parent: _tabAnim, curve: Curves.easeOutCubic);
  late final Animation<double> _tabScale =
      Tween<double>(begin: 0.985, end: 1.0).animate(_tabFade);

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
    // Ordine lasciato in sospeso in una sessione precedente (anche chiusa di
    // colpo dentro la scelta ticket): al primo avvio dello shell il pallino
    // va acceso.
    PendingOrderService().aggiornaPallino();
  }

  @override
  void dispose() {
    if (NavigatorService.shellNavigatorKey == _navKey) {
      NavigatorService.shellNavigatorKey = null;
    }
    if (NavigatorService.switchTab == switchToTab) {
      NavigatorService.switchTab = null;
    }
    _tabAnim.dispose();
    _tab.dispose();
    _routeHighlight.dispose();
    super.dispose();
  }

  void switchToTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    // Aprire il carrello vale come "notifica vista": il pallino si spegne, ma
    // gli ordini in sospeso restano lì. Va fatto qui e non nella schermata,
    // perché nell'IndexedStack quella resta montata e non riparte mai.
    if (index == _tabCarrello) PendingOrderService().segnaVisti();
    // Chiude eventuali dettagli aperti e torna alla radice della tab scelta.
    _navKey.currentState?.popUntil((r) => r.isFirst);
    final bool changed = index != _tab.value;
    _tab.value = index;
    // Anima l'ingresso della nuova tab solo se è cambiata davvero.
    if (changed) _tabAnim.forward(from: 0.0);
  }

  /// Host dei 3 tab, in ascolto di [_tab]: cambiare tab ricostruisce solo
  /// l'IndexedStack (i figli restano montati), non tocca la footer né le route.
  Route<dynamic> _shellHome(RouteSettings settings) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      // Questa rotta non anima mai per conto suo (i tab cambiano dentro), ma è
      // la pagina che si vede SOTTO quando si apre un dettaglio: deve arretrare
      // col parallax mentre il dettaglio la copre, e rientrare durante lo
      // swipe-back. Vedi `CoveredPageParallax`.
      transitionsBuilder: (_, __, secondaryAnimation, child) =>
          CoveredPageParallax(
        secondaryAnimation: secondaryAnimation,
        child: child,
      ),
      pageBuilder: (_, __, ___) => ValueListenableBuilder<int>(
        valueListenable: _tab,
        builder: (_, index, __) => FadeTransition(
          opacity: _tabFade,
          child: ScaleTransition(
            scale: _tabScale,
            child: IndexedStack(index: index, children: _tabs),
          ),
        ),
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
          observers: [_routeObserver],
          onGenerateInitialRoutes: (navigator, initialRoute) =>
              <Route<dynamic>>[
            _shellHome(const RouteSettings(name: _shellHomeRoute)),
          ],
          onGenerateRoute: _onGenerateShellRoute,
        ),
        // Unica footer dell'app: fuori dalle route → fissa in ogni situazione.
        // L'icona accesa è quella del tab, a meno che la rotta in cima non ne
        // imponga un'altra (vedi [_highlightPerRotta]).
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: _tab,
          builder: (_, index, __) => ValueListenableBuilder<int?>(
            valueListenable: _routeHighlight,
            builder: (_, forzato, __) => ValueListenableBuilder<bool>(
              // Pallino blu sul carrello: ordine lasciato in sospeso e non
              // ancora visto. Sta qui e non nelle schermate perché la footer
              // è unica e globale.
              valueListenable: PendingOrderService().pallino,
              builder: (_, sospeso, __) => SharedFooter(
                currentIndex: forzato ?? index,
                onTabSelected: switchToTab,
                badgeCarrello: sospeso,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segnala allo shell quale rotta è in cima al Navigator annidato, così la
/// footer può accendere l'icona giusta anche dentro un dettaglio.
///
/// Sta qui e non nelle singole schermate di proposito: la regola è una tabella
/// sola in [_RootShellState._highlightPerRotta], invece di N schermate che si
/// arrangiano ognuna per conto suo.
class _HighlightObserver extends NavigatorObserver {
  _HighlightObserver({required this.onTop});

  final void Function(String? routeName) onTop;

  void _notifica(Route<dynamic>? route) => onTop(route?.settings.name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notifica(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notifica(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notifica(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _notifica(newRoute);
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
