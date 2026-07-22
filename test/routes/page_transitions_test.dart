import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:OnListClub/routes/page_transitions.dart';

/// App minima con due schermate: '/' (radice) e '/second', su cui si può
/// accendere o spegnere lo swipe-back.
Widget _harness(GlobalKey<NavigatorState> navigatorKey,
    {required bool enableBackGesture}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    onGenerateRoute: (settings) {
      if (settings.name == '/second') {
        return buildAppRoute(
          settings,
          (_) => const Scaffold(body: Text('second')),
          AppTransition.sharedAxis,
          enableBackGesture: enableBackGesture,
        );
      }
      return buildAppRoute(
        settings,
        (_) => const Scaffold(body: Text('first')),
        AppTransition.fade,
      );
    },
  );
}

Future<void> _pushSecond(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
) async {
  navigatorKey.currentState!.pushNamed('/second');
  await tester.pumpAndSettle();
  expect(find.text('second'), findsOneWidget);
}

void main() {
  group('swipe-back', () {
    testWidgets('trascinare dal bordo sinistro torna indietro', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navigatorKey, enableBackGesture: true));
      await _pushSecond(tester, navigatorKey);

      await tester.dragFrom(const Offset(5, 300), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(find.text('second'), findsNothing);
      expect(find.text('first'), findsOneWidget);
    });

    testWidgets('un trascinamento corto rimette la pagina a posto',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navigatorKey, enableBackGesture: true));
      await _pushSecond(tester, navigatorKey);

      // Lento e sotto la metà schermo: non è né un fling né oltre la soglia.
      final gesture = await tester.startGesture(const Offset(5, 300));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('il gesto parte solo dal bordo sinistro', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navigatorKey, enableBackGesture: true));
      await _pushSecond(tester, navigatorKey);

      // Stessa distanza, ma partendo da metà schermo.
      await tester.dragFrom(const Offset(300, 300), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('con enableBackGesture: false il gesto non fa nulla',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navigatorKey, enableBackGesture: false));
      await _pushSecond(tester, navigatorKey);

      await tester.dragFrom(const Offset(5, 300), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(find.text('second'), findsOneWidget);
    });
  });
}
