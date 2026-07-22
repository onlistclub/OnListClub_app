import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:OnListClub/core/models/locale_model.dart';
import 'package:OnListClub/core/models/serata_model.dart';
import 'package:OnListClub/core/utils/size_utils.dart';
import 'package:OnListClub/presentation/event_info_popup_screen/event_info_popup_screen.dart';

/// Test di layout del pop-up info serata.
///
/// Invarianti del design (titolo adattivo a 3 stadi, vedi _PopupCard._fitTitle):
/// - il banner radiale superiore finisce SEMPRE prima della pillola data
///   (Rectangle 211 @134, Rectangle 213 @143 → 9px di stacco);
/// - il blocco titolo ha ALTEZZA FISSA (1 riga a 45px): nomi più lunghi
///   rimpiccioliscono il font su 1 riga (45→22px) e solo oltre vanno a
///   2 righe a 22px — il banner e il contenuto sotto NON si spostano mai.
void main() {
  // Senza questo, i widget test renderizzano con un font di fallback e ogni
  // titolo andrebbe a capo a caso: il wrap misurato non direbbe nulla di
  // quello che si vede sul device. Carichiamo l'HelveticaNeue vero.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('HelveticaNeue');
    for (final file in const [
      'assets/fonts/HelveticaNeueLight.otf',
      'assets/fonts/HelveticaNeueRoman.otf',
      'assets/fonts/HelveticaNeueMedium.otf',
      'assets/fonts/HelveticaNeueBold.otf',
    ]) {
      loader.addFont(
          File(file).readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  });

  SerataModel serataCon(String nome) => SerataModel(
        id: 'e1',
        clubId: 'c1',
        nome: nome,
        data: DateTime.now().add(const Duration(days: 7)),
        oraApertura: '22:00',
        oraChiusura: '04:00',
        generiMusicali: const ['Reggaeton', 'Latin'],
        dressCode: 'Libero',
        etaMinima: '18+',
      );

  const club = LocaleModel(
    id: 'c1',
    nome: 'Test Club',
    indirizzo: 'Via di Monte Testaccio 68/69',
    nomeCitta: 'Roma',
  );

  Future<void> pumpPopup(WidgetTester tester, String nome) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      // Key diversa per nome: senza, una seconda pumpPopup nello stesso test
      // riuserebbe la route già creata (onGenerateRoute non viene richiamato)
      // e si finirebbe per misurare due volte lo stesso titolo.
      key: ValueKey(nome),
      // Replica quel che fa il widget `Sizer` in main.dart: R.sp legge da
      // SizeUtils, che va inizializzato prima che la schermata si costruisca.
      builder: (context, child) => LayoutBuilder(builder: (ctx, constraints) {
        SizeUtils.setScreenSize(constraints, Orientation.portrait);
        return child!;
      }),
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => const EventInfoPopupScreen(),
        settings: RouteSettings(
          name: settings.name,
          arguments: {'serata': serataCon(nome), 'club': club},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Quanto il banner "invade" la pillola data, in px logici.
  /// <= 0 significa nessuna sovrapposizione.
  double overlap(WidgetTester tester) {
    final banner = tester.getRect(find.byKey(bannerKey));
    final pill = tester.getRect(find.byKey(datePillKey));
    return banner.bottom - pill.top;
  }

  testWidgets('titolo corto: la pillola data sta sotto il banner',
      (tester) async {
    await pumpPopup(tester, 'Spring Party');
    expect(find.byKey(datePillKey), findsOneWidget);
    expect(overlap(tester), lessThanOrEqualTo(0));
  });

  testWidgets('titolo medio: la pillola data resta sotto il banner',
      (tester) async {
    await pumpPopup(tester, 'Reggaeton Special');
    expect(find.byKey(datePillKey), findsOneWidget);
    expect(overlap(tester), lessThanOrEqualTo(0));
  });

  testWidgets(
      'titolo medio: shrink su 1 riga, banner fisso e layout sotto immobile',
      (tester) async {
    await pumpPopup(tester, 'Spring Party');
    final bannerCorto = tester.getRect(find.byKey(bannerKey));
    final pillCorto = tester.getRect(find.byKey(datePillKey));

    await pumpPopup(tester, 'Reggaeton Special');
    final bannerLungo = tester.getRect(find.byKey(bannerKey));
    final pillLungo = tester.getRect(find.byKey(datePillKey));

    // Stadio 2: il titolo medio si rimpicciolisce (tra 22 e 45 design px)
    // restando su UNA riga — non va a capo.
    final title = tester.widget<Text>(find.text('REGGAETON SPECIAL'));
    expect(title.style!.fontSize, lessThan(45.0));
    expect(title.style!.fontSize, greaterThanOrEqualTo(22.0));
    final titoloH = tester.getRect(find.text('REGGAETON SPECIAL')).height;
    expect(titoloH, lessThan(45.0 * 1.5)); // niente seconda riga

    // Il blocco titolo è ad altezza fissa: banner e pillola data NON si
    // spostano di un pixel rispetto al titolo corto.
    expect(bannerLungo.height, closeTo(bannerCorto.height, 0.01));
    expect(pillLungo.top, closeTo(pillCorto.top, 0.01));
  });

  testWidgets(
      'titolo lunghissimo: 2 righe alla dimensione minima, mai più di 2',
      (tester) async {
    await pumpPopup(tester, 'Nome Serata Molto Molto Lungo Che Non Ci Sta Mai');
    final finder = find.text('NOME SERATA MOLTO MOLTO LUNGO CHE NON CI STA MAI');
    final title = tester.widget<Text>(finder);
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    // Stadio 3: 2 righe alla dimensione minima (22 design px, scalata con
    // R.sp: viewport test 393 su base 390).
    expect(title.style!.fontSize, closeTo(22 * 393 / 390, 0.01));
    // Il testo occupa davvero 2 righe...
    expect(tester.getRect(finder).height, greaterThan(22 * 1.5));
    // ...dentro il blocco fisso: la pillola resta comunque sotto il banner.
    expect(overlap(tester), lessThanOrEqualTo(0));
  });
}
