import 'package:flutter/material.dart';

import '../../core/services/navigator_service.dart';
import '../../core/services/pending_order_service.dart';
import '../../routes/app_routes.dart';
import '../../routes/page_transitions.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/root_shell_scope.dart';
import '../../widgets/shared_footer.dart';
import '../home_screen/home_screen.dart';
import '../orders_screen/orders_screen.dart';
import '../cart_screen/cart_screen.dart';

// `RootShellScope` viveva in questo file: ri-esportato perché diverse
// schermate lo importano ancora da qui.
export '../../widgets/root_shell_scope.dart';

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

  /// Nessuna icona accesa nella footer.
  static const int _nessunaTab = -1;

  /// Rotte che forzano un'icona diversa da quella del tab.
  ///
  /// Ricerca e Account non appartengono a nessuno dei tre tab: lì la footer
  /// resta tutta spenta, altrimenti resterebbe acceso il pallino della tab da
  /// cui sei arrivato (di solito Home) indicando una schermata in cui non sei.
  static const Map<String, int> _highlightPerRotta = {
    AppRoutes.bookingScreen: _tabCarrello,
    AppRoutes.cartScreen: _tabCarrello,
    AppRoutes.nearbyClubsScreen: _nessunaTab,
    AppRoutes.profileScreen: _nessunaTab,
  };

  /// Nome della rotta in cima al Navigator annidato. Serve alla navbar unica
  /// per scegliere la sua variante (vedi [_navbar]).
  final ValueNotifier<String?> _rottaInCima =
      ValueNotifier<String?>(_shellHomeRoute);

  late final _HighlightObserver _routeObserver =
      _HighlightObserver(onTop: _aggiornaHighlight);

  void _aggiornaHighlight(String? routeName) {
    _routeHighlight.value = _highlightPerRotta[routeName];
    _rottaInCima.value = routeName;
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
    _rottaInCima.dispose();
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

  /// La navbar unica dell'app.
  ///
  /// Le due varianti che prima si sceglievano le schermate ora le decide lo
  /// shell, che sa già sia il tab attivo sia la rotta in cima:
  ///  - `isHome` quando si guarda davvero la Home (tab Home e nessun
  ///    dettaglio sopra);
  ///  - profilo "muto" quando la rotta in cima è l'Account: sei già lì, il tap
  ///    non deve fare nulla.
  Widget _navbar() {
    return AnimatedBuilder(
      animation: Listenable.merge([_tab, _rottaInCima]),
      builder: (_, __) {
        final String? rotta = _rottaInCima.value;
        final bool suHome =
            rotta == _shellHomeRoute && _tab.value == _tabHome;
        final bool suAccount = rotta == AppRoutes.profileScreen;
        final bool suRicerca = rotta == AppRoutes.nearbyClubsScreen;
        return CustomTopBar(
          isHome: suHome,
          // Su Account e su Ricerca l'icona corrispondente resta muta (ci sei
          // già, il tap non deve portarti dove sei) e si ACCENDE, mentre
          // l'altra si attenua: stessa logica della footer.
          onProfileTap: suAccount ? () {} : null,
          onSearchTap: suRicerca ? () {} : null,
          profiloAttivo: suAccount,
          searchAttiva: suRicerca,
        );
      },
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
        // La navbar sta FUORI dal Navigator, esattamente come la footer: è una
        // sola per tutta la sessione, quindi non si ricostruisce a ogni
        // navigazione e non scorre con lo swipe. Prima ne montava una ognuna
        // delle 12 schermate, e durante la transizione se ne vedevano DUE che
        // si incrociavano — l'effetto "si ricarica ogni volta".
        //
        // Il SafeArea sta qui e non nelle schermate: quelle che ne hanno uno
        // proprio se lo ritrovano a padding zero, quindi resta innocuo.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _navbar(),
              Expanded(
                child: Navigator(
                  key: _navKey,
                  observers: [_routeObserver],
                  onGenerateInitialRoutes: (navigator, initialRoute) =>
                      <Route<dynamic>>[
                    _shellHome(const RouteSettings(name: _shellHomeRoute)),
                  ],
                  onGenerateRoute: _onGenerateShellRoute,
                ),
              ),
            ],
          ),
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

