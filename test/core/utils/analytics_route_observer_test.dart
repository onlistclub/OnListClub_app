import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:OnListClub/core/services/analytics_service.dart';
import 'package:OnListClub/core/utils/analytics_route_observer.dart';
import 'package:OnListClub/routes/app_routes.dart';
import 'package:OnListClub/routes/page_transitions.dart';

/// Rotta finta per qualsiasi nome: basta che sia una pagina vera. Come
/// `AppRoutes.onGenerateRoute`, non esiste una rotta '/' (il Navigator la
/// chiede quando l'initialRoute inizia con '/').
Route<dynamic>? _pagina(RouteSettings settings) => settings.name == '/'
    ? null
    : buildAppRoute(
        settings,
        (_) => Scaffold(body: Text(settings.name ?? '')),
        AppTransition.fade,
      );

void main() {
  late List<(String, Map<String, dynamic>)> eventi;

  setUp(() {
    eventi = [];
    AnalyticsService.registroPerTest = (e, m) => eventi.add((e, m));
    AnalyticsService.resetPerTest();
  });

  tearDown(() => AnalyticsService.registroPerTest = null);

  List<String> schermate() => eventi
      .where((e) => e.$1.startsWith('screen_'))
      .map((e) => e.$1 + (e.$2['ritorno'] == true ? ' (ritorno)' : ''))
      .toList();

  testWidgets('push, pop, dialog e replace sul Navigator radice',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [AnalyticsRouteObserver()],
      initialRoute: AppRoutes.splashScreen,
      onGenerateRoute: _pagina,
    ));
    await tester.pumpAndSettle();

    nav.currentState!.pushNamed(AppRoutes.clubDetailScreen);
    await tester.pumpAndSettle();

    // Un dialog non è una schermata: né aprirlo né chiuderlo conta.
    showDialog<void>(
      context: nav.currentContext!,
      builder: (_) => const AlertDialog(content: Text('x')),
    );
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();

    nav.currentState!.pop();
    await tester.pumpAndSettle();

    nav.currentState!.pushReplacementNamed(AppRoutes.bookingScreen);
    await tester.pumpAndSettle();

    nav.currentState!.pushNamedAndRemoveUntil(
        AppRoutes.tavoloDetailScreen, (_) => false);
    await tester.pumpAndSettle();

    expect(schermate(), [
      'screen_splash',
      'screen_club_detail',
      'screen_splash (ritorno)',
      'screen_booking_selection',
      'screen_tavolo_detail',
    ]);
    // Ogni schermata lasciata ha il suo page_exit.
    expect(eventi.where((e) => e.$1 == 'page_exit').length, 4);
  });

  testWidgets('shell annidato: niente doppione iniziale, ritorno sulla tab',
      (tester) async {
    final shellNav = GlobalKey<NavigatorState>();
    AnalyticsService.nomeTabAttiva = () => 'orders_list';

    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [AnalyticsRouteObserver()],
      initialRoute: AppRoutes.homeScreen,
      onGenerateRoute: (settings) => settings.name == '/'
          ? null
          : buildAppRoute(
        settings,
        (_) => Navigator(
          key: shellNav,
          observers: [AnalyticsRouteObserver(annidato: true)],
          initialRoute: AnalyticsRouteObserver.rottaTabShell,
          onGenerateRoute: _pagina,
        ),
        AppTransition.fade,
      ),
    ));
    await tester.pumpAndSettle();

    shellNav.currentState!.pushNamed(AppRoutes.nearbyClubsScreen);
    await tester.pumpAndSettle();
    shellNav.currentState!.pop();
    await tester.pumpAndSettle();

    expect(schermate(), [
      'screen_orders_list',
      'screen_search_nearby',
      'screen_orders_list (ritorno)',
    ]);
  });

  testWidgets('cambio tab: i dettagli chiusi in blocco non risultano visti',
      (tester) async {
    // Stesso schema di RootShell.switchToTab.
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [AnalyticsRouteObserver()],
      initialRoute: AppRoutes.splashScreen,
      onGenerateRoute: _pagina,
    ));
    await tester.pumpAndSettle();
    nav.currentState!.pushNamed(AppRoutes.clubDetailScreen);
    nav.currentState!.pushNamed(AppRoutes.bookingScreen);
    await tester.pumpAndSettle();
    eventi.clear();

    AnalyticsService.senzaTracciareNavigazione(
      () => nav.currentState!.popUntil((r) => r.isFirst),
    );
    AnalyticsService.mostraSchermata('orders_list');
    await tester.pumpAndSettle();

    expect(eventi.map((e) => e.$1).toList(), ['page_exit', 'screen_orders_list']);
    expect(eventi.first.$2['page_name'], 'booking_selection');
  });

  test('nomi delle rotte', () {
    expect(AnalyticsRouteObserver.nomeSchermata(AppRoutes.nearbyClubsScreen),
        'search_nearby');
    expect(
        AnalyticsRouteObserver.nomeSchermata(AppRoutes.paymentSuccessScreen),
        'payment_success');
    expect(AnalyticsRouteObserver.nomeSchermata(null), isNull);

    // Rotta dello shell con un dettaglio in cima: vale il dettaglio.
    AnalyticsService.rottaInCimaShell = () => AppRoutes.clubDetailScreen;
    expect(AnalyticsRouteObserver.nomeSchermata(AppRoutes.homeScreen),
        'club_detail');
    // Nessun dettaglio: vale la tab attiva (Home se lo shell non c'è ancora).
    AnalyticsService.rottaInCimaShell = () => AnalyticsRouteObserver.rottaTabShell;
    expect(AnalyticsRouteObserver.nomeSchermata(AppRoutes.homeScreen), 'home');
  });
}
