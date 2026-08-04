// Regressione: le 4 facce del bundle devono essere agganciate dai rispettivi
// FontWeight. Se il w500 ricade sul Roman (com'è successo finché la famiglia si
// chiamava `HelveticaNeue` e collideva con la famiglia di sistema iOS), il testo
// del design esce ~25% più sottile del dovuto.
//
// Le 4 facce hanno advance distinti, quindi la larghezza di layout è
// un'impronta digitale della faccia effettivamente usata.
//
// NB: `flutter test` non carica i font dichiarati nel pubspec (il layout usa
// Ahem), quindi qui li registriamo a mano con FontLoader — stesso percorso
// engine (RegisterTypeface + matchStyleCSS3) usato per i font asset.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _text = 'Jesolo - Via Roma Destra 120';

// I file BUNDLE, cioè quelli dichiarati nel pubspec: `OnlistHN-*.otf`, che
// hanno anche il nome INTERNO riscritto a "OnlistHN". I vecchi
// `HelveticaNeue*.otf` sono rimasti sul disco ma non fanno più parte dell'app:
// puntare il test su quelli proverebbe file che nessuno carica.
const _faces = <String, String>{
  'Light': 'assets/fonts/OnlistHN-Light.otf',
  'Roman': 'assets/fonts/OnlistHN-Roman.otf',
  'Medium': 'assets/fonts/OnlistHN-Medium.otf',
  'Bold': 'assets/fonts/OnlistHN-Bold.otf',
};

Future<void> _loadFamily(String family, Iterable<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(File(path).readAsBytes().then((b) => b.buffer.asByteData()));
  }
  await loader.load();
}

double _width(String family, FontWeight weight) {
  final painter = TextPainter(
    text: TextSpan(
      text: _text,
      style: TextStyle(fontFamily: family, fontSize: 16, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ogni FontWeight aggancia la faccia corrispondente', () async {
    // Riferimento: ogni faccia sotto una famiglia propria, nessuna ambiguità.
    final expected = <String, double>{};
    for (final entry in _faces.entries) {
      final family = 'Ref${entry.key}';
      await _loadFamily(family, [entry.value]);
      expected[entry.key] = _width(family, FontWeight.w400);
    }

    // Le 4 facce devono essere distinguibili, altrimenti il test non prova nulla.
    final widths = expected.values.toSet();
    expect(widths.length, 4, reason: 'le facce devono avere advance distinti');

    // Le 4 facce registrate insieme, come fa il bundle.
    await _loadFamily('OnlistHN', _faces.values);

    expect(_width('OnlistHN', FontWeight.w300), expected['Light'],
        reason: 'w300 deve agganciare Light');
    expect(_width('OnlistHN', FontWeight.w400), expected['Roman'],
        reason: 'w400 deve agganciare Roman');
    expect(_width('OnlistHN', FontWeight.w500), expected['Medium'],
        reason: 'w500 deve agganciare Medium, non ricadere su Roman');
    expect(_width('OnlistHN', FontWeight.w700), expected['Bold'],
        reason: 'w700 deve agganciare Bold');
  });

  test('w600 non esiste nel bundle e ricade sul Bold', () async {
    // Documenta il comportamento: nel codice si usa w700 esplicito.
    await _loadFamily('OnlistHN600', _faces.values);
    expect(_width('OnlistHN600', FontWeight.w600),
        _width('OnlistHN600', FontWeight.w700));
  });
}
