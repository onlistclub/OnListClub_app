import 'package:flutter/material.dart';

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

  /// Sfondo schermate onboarding (Splash, Login, Sign up, ecc.).
  /// `radial-gradient(98% 98% at 3% 1%, #0107D6 0%, #000 100%)`
  static const RadialGradient onboardingBackground = RadialGradient(
    center: Alignment(-0.94, -0.98), // ≈ at 3% 1%
    radius: 1.4, // copre 98% 98%
    colors: [blueGradientStart, black],
  );

  // ── Gradienti card ──────────────────────────────────────────────────────

  /// Card grande singolo ticket (schermate 12, 13).
  /// `linear-gradient(180deg, #000 0%, #0015FF 100%)`
  static const LinearGradient cardSingleTicket = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [black, blueGradientEnd],
  );

  /// Card sintetica carrello/ordini (schermate 14, 17, 18).
  /// `linear-gradient(180deg, #1E00FF 0%, #020011 100%)`
  static const LinearGradient cardSummary = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [blueElectric, blueDeepNear],
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

  /// Bottone PRENOTA card ticket (vertical gradient).
  /// `linear-gradient(180deg, #000 0%, #201064 100%)`
  static const LinearGradient bookButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [black, blueViolet],
  );

  /// Bottone PRENOTA card serata home (horizontal).
  /// `linear-gradient(90deg, #1500B3 0%, #201064 100%)`
  static const LinearGradient bookEventButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [blueIntense2, blueViolet],
  );
}
