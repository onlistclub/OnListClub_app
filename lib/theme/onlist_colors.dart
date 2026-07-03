import 'dart:math' as math;

import 'package:flutter/material.dart';

/// `RadialGradient` di Flutter disegna un cerchio il cui raggio è sempre
/// relativo al lato PIÙ CORTO del box (vedi doc di `RadialGradient.radius`).
/// Il gradiente ufficiale è invece un'ellisse RUOTATA col picco blu nell'angolo
/// alto-sinistra (il CSS Figma aveva proprio il warning "rotation not
/// supported"). Parametri ottenuti fittando i pixel reali del PNG ufficiale
/// (`docs/figma_screen/off/02 - Autenticazione.png`, 393×852): per ogni pixel
/// di sfondo si risolve `d = 1 - B/214` (214 = canale blu del picco #0107D6) e
/// si minimizza lo scarto su tutta l'immagine. Ottimo globale:
///   - semiasse "orizzontale" → 1.05 × larghezza
///   - semiasse "verticale"   → 1.08 × altezza
///   - rotazione dell'ellisse  → −23°
/// Errore medio residuo ≈ 0.7% del canale blu su ~32k pixel (tutte le zone
/// entro ±2). La rotazione è ciò che tiene più blu nella diagonale verso il
/// basso-destra, che un'ellisse ad assi dritti sottostimava. Il transform
/// costruisce M = T(C)·Rot(θ)·Scale(sx,sy)·T(−C): Flutter lo usa come
/// localMatrix del gradiente, quindi il cerchio base diventa l'ellisse ruotata
/// voluta, col centro fisso. Frazioni relative a larghezza/altezza reali → il
/// gradiente scala con qualsiasi schermo.
class _EllipticalGradientTransform extends GradientTransform {
  const _EllipticalGradientTransform();

  /// Semiasse "orizzontale" come frazione della larghezza dello schermo.
  static const double _fx = 1.05;

  /// Semiasse "verticale" come frazione dell'altezza dello schermo.
  static const double _fy = 1.08;

  /// Rotazione dell'ellisse attorno al centro (gradi → radianti).
  static const double _rotation = -23.0 * math.pi / 180.0;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Raggio base del cerchio disegnato da RadialGradient (lato corto).
    final double base =
        OnlistColors.onboardingRadius * math.min(bounds.width, bounds.height);
    if (base == 0) return null;
    // Scala ogni asse per raggiungere il semiasse voluto in px.
    final double scaleX = (_fx * bounds.width) / base;
    final double scaleY = (_fy * bounds.height) / base;
    final Offset center = bounds.topLeft +
        OnlistColors.onboardingBackgroundCenter.alongSize(bounds.size);
    // M = T(C)·Rot(θ)·Scale·T(−C): ruota e stira il cerchio base tenendo C fermo.
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0.0, 1.0)
      ..rotateZ(_rotation)
      ..scaleByDouble(scaleX, scaleY, 1.0, 1.0)
      ..translateByDouble(-center.dx, -center.dy, 0.0, 1.0);
  }
}

/// Tinte e gradienti ufficiali del design system Onlist Club.
///
/// Valori canonici dichiarati in `.claude/CLAUDE.md` §2 e validati contro
/// `docs/figma_screen/all-layers-mvp.txt`. Non aggiungere colori non
/// presenti nel design system — propornili prima a Luca.
class OnlistColors {
  OnlistColors._();

  // ── Palette base ────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Blu brand
  static const Color bluePrimary = Color(0xFF1900D8);   // brand
  static const Color blueElectric = Color(0xFF1E00FF);  // accenti/CTA
  static const Color blueDeep = Color(0xFF060037);      // fondo schermate
  static const Color blueViolet = Color(0xFF201064);    // fine gradiente brand
  static const Color blueIntense1 = Color(0xFF120099);
  static const Color blueIntense2 = Color(0xFF1500B3);
  static const Color blueIntense3 = Color(0xFF1800D2);
  static const Color blueGradientStart = Color(0xFF0107D6);
  static const Color blueGradientStart2 = Color(0xFF0009FF);
  static const Color blueGradientEnd = Color(0xFF0015FF);
  static const Color blueDeepNear = Color(0xFF020011);
  static const Color blueIOS = Color(0xFF007AFF);
  static const Color blueButtonPrimary = Color(0xFF000599); // Controls/Buttons/Primary (Figma)

  // Grigi neutri
  static const Color textSecondary = Color(0xFF8E8E93);

  // Funzionali social (immutabili — brand di terze parti)
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleRed = Color(0xFFEA4335);

  // ── Gradienti schermata ─────────────────────────────────────────────────

  /// Sfondo standard delle schermate dark (Home, Carrello, Ordini, ecc.).
  /// `linear-gradient(180deg, #000 0%, #060037 100%)`
  static const LinearGradient screenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [black, blueDeep],
  );

  /// Sfondo schermate pre-home (Splash, Login, Sign up, Verifica, Permessi GPS,
  /// Posizione manuale). Ellisse blu RUOTATA con picco #0107D6 nell'angolo
  /// alto-sinistra che sfuma a nero. Centro e colori dal CSS Figma ufficiale
  /// (accedi.css / start.css: `at 3.94% 1.58%, #0107D6 → #000000`); assi e
  /// rotazione dell'ellisse sono fittati sui pixel reali del PNG ufficiale
  /// (vedi [_EllipticalGradientTransform]) perché il CSS aveva il warning
  /// "rotation not supported" e i suoi 98.42% non corrispondevano ai pixel.
  ///   - 3.94% → asse X normalizzato (-1..+1): 2*0.0394 - 1 = -0.9212
  ///   - 1.58% → asse Y normalizzato (-1..+1): 2*0.0158 - 1 = -0.9684
  static const Alignment onboardingBackgroundCenter =
      Alignment(-0.9212, -0.9684); // 3.94% 1.58% (alto-sinistra)

  /// Raggio base del [RadialGradient] pre-home (frazione del lato corto).
  /// Il valore preciso è irrilevante: [_EllipticalGradientTransform] riscala
  /// entrambi gli assi ai semiassi misurati, ma lo teniamo per chiarezza.
  static const double onboardingRadius = 0.9842;

  static const RadialGradient onboardingBackground = RadialGradient(
    center: onboardingBackgroundCenter,
    radius: onboardingRadius,
    colors: [blueGradientStart, black], // #0107D6 → #000000
    stops: [0.0, 1.0],
    transform: _EllipticalGradientTransform(),
  );

  // ── Gradienti card ──────────────────────────────────────────────────────

  /// Card grande singolo ticket (schermate 12, 13).
  /// `linear-gradient(180deg, #000 0%, #0015FF 100%)`
  static const LinearGradient cardSingleTicket = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [black, blueGradientEnd],
  );

  /// Card sintetica carrello/ordini ("Ticket riepilogo ordini" / "Ticket nel
  /// carrello"). `linear-gradient(180deg, #1E00FF 0%, #020011 100%)`
  static const LinearGradient cardSummary = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [blueElectric, blueDeepNear],
  );

  /// Card "Club consigliati" (Home) e "Prossime serate" (Club detail).
  /// Valore UFFICIALE: `linear-gradient(90deg, #000 28.37%, #000B83 79.33%)`.
  /// È un blu profondo (NON il viola #1500B3/#110091 usato per errore prima).
  static const LinearGradient cardEvent = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [black, Color(0xFF000B83)],
    stops: [0.2837, 0.7933],
  );

  /// Card "Ticket disponibili" (lista prevendite, booking).
  /// Valore UFFICIALE: `linear-gradient(180deg, rgba(0,0,0,.5), rgba(0,21,255,.5))`
  /// (blu semitrasparente, NON il solido viola #1900D8 usato prima).
  static const LinearGradient cardTicketAvailable = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x80000000), Color(0x800015FF)],
  );

  // ── Gradienti bottoni ───────────────────────────────────────────────────

  /// CTA primario full-width (AGGIUNGI AL CARRELLO, ORDINA IL TUO POSTO ORA,
  /// TORNA NELLA HOME, CONTINUA L'ORDINE).
  /// `linear-gradient(90deg, #1800D2 19.48%, #120099 100%)`
  static const LinearGradient primaryCTA = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [blueIntense3, blueIntense1],
    stops: [0.1948, 1.0],
  );

  /// Bottone PRENOTA unificato (card ticket booking + card serata club detail).
  /// Valore UFFICIALE Figma `Rectangle 164`:
  /// `linear-gradient(180deg, #1E00FF 0%, #201064 100%)`.
  /// Usato come stile standard di tutti i pulsanti "PRENOTA" dell'app.
  static const LinearGradient bookButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [blueElectric, blueViolet],
  );

  /// Bottone PRENOTA card serata home (horizontal).
  /// `linear-gradient(90deg, #1500B3 0%, #201064 100%)`
  static const LinearGradient bookEventButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [blueIntense2, blueViolet],
  );
}
