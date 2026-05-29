/// Facade responsive dell'app: la classe [R].
///
/// Costruita SOPRA [SizeUtils] (vedi `size_utils.dart`), che è già inizializzato
/// dal widget `Sizer` in `main.dart` prima che qualsiasi schermata venga
/// costruita. Per questo `R` non ha bisogno di un proprio `init(context)`:
/// legge direttamente `SizeUtils.width` / `SizeUtils.height`.
///
/// Uso tipico nelle schermate:
///   fontSize: R.sp(16)        // testo scalato sulla larghezza, con tetto
///   width: R.w(50)            // 50% della larghezza schermo
///   height: R.h(20)           // 20% dell'altezza schermo
///
/// NOTA preview web: su Flutter Web/desktop `main.dart` incapsula i contenuti in
/// un `ConstrainedBox(maxWidth: 430)`, mentre `SizeUtils` misura l'intera
/// finestra. Per viewport ≤430 (tutti i telefoni emulati) i due coincidono; per
/// viewport più larghe (tablet emulato nel browser) `R` calcola sulla finestra
/// piena. Su device reali il cap non esiste, quindi `R` è sempre corretto.
library;

import 'size_utils.dart';

class R {
  R._();

  /// Larghezza di riferimento del design Figma (base iPhone 12/13).
  static const double _baseWidth = 390;

  /// Soglia oltre la quale consideriamo lo schermo un tablet.
  static const double tabletBreakpoint = 600;

  /// Larghezza attuale dello schermo (lato corto in portrait).
  static double get width => SizeUtils.width;

  /// Altezza attuale dello schermo.
  static double get height => SizeUtils.height;

  /// `true` su schermi larghi (tablet).
  static bool get isTablet => width >= tabletBreakpoint;

  /// `true` sui telefoni più stretti (es. Galaxy S7/S8, iPhone SE 1ª gen).
  static bool get isSmallPhone => width < 360;

  /// Larghezza pari a [percent]% della larghezza schermo.
  static double w(double percent) => width * percent / 100;

  /// Altezza pari a [percent]% dell'altezza schermo.
  static double h(double percent) => height * percent / 100;

  /// Fattore di scala lineare basato sulla larghezza, con tetto.
  ///
  /// Limitato a `[0.85, 1.30]` così:
  /// - sui telefoni stretti i testi non si rimpiccioliscono troppo;
  /// - sui tablet non diventano spropositati (problema dei prezzi giganti).
  static double get scale => (width / _baseWidth).clamp(0.85, 1.30);

  /// Dimensione (tipicamente font) scalata sulla larghezza, con tetto.
  static double sp(double size) => size * scale;
}
