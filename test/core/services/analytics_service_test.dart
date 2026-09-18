import 'package:flutter_test/flutter_test.dart';
import 'package:OnListClub/core/services/analytics_service.dart';

void main() {
  late List<(String, Map<String, dynamic>)> eventi;
  late DateTime adesso;

  setUp(() {
    eventi = [];
    adesso = DateTime(2026, 9, 17, 22, 0);
    AnalyticsService.orologio = () => adesso;
    AnalyticsService.registroPerTest = (e, m) => eventi.add((e, m));
    AnalyticsService.resetPerTest();
  });

  tearDown(() {
    AnalyticsService.registroPerTest = null;
    AnalyticsService.orologio = DateTime.now;
  });

  List<String> nomi() => eventi.map((e) => e.$1).toList();

  group('schermate', () {
    test('ogni page_exit chiude la schermata precedente con la sua durata', () {
      AnalyticsService.mostraSchermata('home');
      adesso = adesso.add(const Duration(seconds: 12));
      AnalyticsService.mostraSchermata('club_detail');

      expect(nomi(), ['screen_home', 'page_exit', 'screen_club_detail']);
      expect(eventi[1].$2['page_name'], 'home');
      expect(eventi[1].$2['duration_seconds'], 12);
      expect(eventi[2].$2['referrer_page'], 'home');
      expect(AnalyticsService.currentScreen, 'club_detail');
    });

    test('il ritorno è marcato e la stessa schermata non si ripete', () {
      AnalyticsService.mostraSchermata('home');
      AnalyticsService.mostraSchermata('home');
      AnalyticsService.mostraSchermata('club_detail');
      AnalyticsService.mostraSchermata('home', ritorno: true);

      expect(nomi().where((n) => n == 'screen_home').length, 2);
      expect(eventi.last.$2['ritorno'], true);
    });

    test('le navigazioni sospese non vengono registrate', () {
      AnalyticsService.mostraSchermata('booking_selection');
      AnalyticsService.senzaTracciareNavigazione(() {
        AnalyticsService.mostraSchermata('club_detail', ritorno: true);
      });
      expect(nomi(), ['screen_booking_selection']);
    });
  });

  group('sessione', () {
    test('ogni evento porta session_id e seq crescente', () {
      AnalyticsService.log(event: 'a');
      AnalyticsService.log(event: 'b');
      expect(eventi[0].$2['session_id'], AnalyticsService.sessionId);
      expect(eventi[1].$2['seq'], (eventi[0].$2['seq'] as int) + 1);
      expect(eventi[0].$2['client_ts'], isA<String>());
    });

    test('pausa breve: stessa sessione, la schermata torna con ritorno', () {
      final id = AnalyticsService.sessionId;
      AnalyticsService.mostraSchermata('home');
      adesso = adesso.add(const Duration(seconds: 40));
      AnalyticsService.suAppNascosta();
      adesso = adesso.add(const Duration(minutes: 5));
      AnalyticsService.suAppVisibile();

      expect(nomi(), ['screen_home', 'page_exit', 'session_end', 'screen_home']);
      expect(eventi[2].$2['duration_seconds'], 40);
      expect(eventi[2].$2['page_name'], 'home');
      expect(eventi.last.$2['ritorno'], true);
      expect(AnalyticsService.sessionId, id);
    });

    test('pausa lunga: nuova sessione che riparte dalla schermata lasciata', () {
      final id = AnalyticsService.sessionId;
      AnalyticsService.mostraSchermata('search_nearby');
      AnalyticsService.suAppNascosta();
      adesso = adesso.add(AnalyticsService.pausaNuovaSessione);
      AnalyticsService.suAppVisibile();

      expect(AnalyticsService.sessionId, isNot(id));
      expect(nomi().sublist(3), ['session_start', 'screen_search_nearby']);
      expect(eventi[3].$2['motivo'], 'ritorno_dopo_pausa');
      expect(eventi.last.$2.containsKey('ritorno'), isFalse);
      expect(eventi.last.$2['session_id'], AnalyticsService.sessionId);
    });

    test('la durata di session_end esclude il tempo in background', () {
      AnalyticsService.mostraSchermata('home');
      adesso = adesso.add(const Duration(seconds: 30));
      AnalyticsService.suAppNascosta();
      adesso = adesso.add(const Duration(minutes: 10));
      AnalyticsService.suAppVisibile();
      adesso = adesso.add(const Duration(seconds: 20));
      AnalyticsService.suAppNascosta();

      final fine = eventi.lastWhere((e) => e.$1 == 'session_end');
      expect(fine.$2['duration_seconds'], 50);
    });

    test('navigazione con app in background: si riapre quella schermata', () {
      AnalyticsService.mostraSchermata('home');
      AnalyticsService.suAppNascosta();
      AnalyticsService.mostraSchermata('notifications');
      AnalyticsService.suAppVisibile();

      expect(nomi().last, 'screen_notifications');
    });
  });

  group('valori', () {
    test('importoEuro legge i prezzi mostrati nell\'app', () {
      expect(AnalyticsService.importoEuro('25€'), 25);
      expect(AnalyticsService.importoEuro('12,50 €'), 12.5);
      expect(AnalyticsService.importoEuro('1.200€'), 1200);
      expect(AnalyticsService.importoEuro('1.234,50€'), 1234.5);
      expect(AnalyticsService.importoEuro('12.5'), 12.5);
      expect(AnalyticsService.importoEuro(30), 30);
      expect(AnalyticsService.importoEuro('—'), isNull);
      expect(AnalyticsService.importoEuro(null), isNull);
    });

    test('le coordinate sono arrotondate a ~1 km', () {
      expect(AnalyticsService.arrotondaCoordinata(45.739635), 45.74);
      expect(AnalyticsService.arrotondaCoordinata(7.42507), 7.43);
      expect(AnalyticsService.arrotondaCoordinata(null), isNull);
    });
  });
}
