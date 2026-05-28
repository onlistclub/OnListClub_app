import 'package:flutter/material.dart';
import 'onlist_colors.dart';

/// Stili tipografici del design Onlist Club (HelveticaNeue).
///
/// Mappati 1:1 ai valori del Figma (`docs/figma_screen/all-layers-mvp.txt`).
/// Il design originale usa famiglie miste `Helvetica` / `Helvetica Neue` /
/// `Helvetica Light` / `SF Compact`. Su mobile li accorpiamo tutti su
/// `HelveticaNeue` (declinato per peso) — la resa visiva è equivalente.
class OnlistTextStyles {
  OnlistTextStyles._();

  static const String _family = 'HelveticaNeue';

  /// Helper per stili ad-hoc su HelveticaNeue (sostituisce GoogleFonts.inter(...)
  /// nelle schermate con molti stili inline). Stessa firma dei parametri usati.
  static TextStyle hn({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: _family,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // ── Titoli grandi (display) ─────────────────────────────────────────────

  /// Titolo "ORDINE" della schermata 15. 64/63 w300 LS -0.07em.
  static const TextStyle display64Light = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w300,
    fontSize: 64,
    height: 63 / 64,
    letterSpacing: -0.07 * 64,
    color: OnlistColors.white,
  );

  /// "Accedi" / "Registrati" headline auth. 40/40 w400.
  static const TextStyle display40Regular = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 40,
    height: 1.0,
    color: OnlistColors.white,
  );

  /// "EFFETTUATO" schermata 15. 36/36 w300 LS -0.07em.
  static const TextStyle title36Light = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w300,
    fontSize: 36,
    height: 1.0,
    letterSpacing: -0.07 * 36,
    color: OnlistColors.white,
  );

  /// Nome locale grande in home/club-detail. 36/36 w700 LS -0.08em.
  static const TextStyle title36Bold = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    fontSize: 36,
    height: 1.0,
    letterSpacing: -0.08 * 36,
    color: OnlistColors.white,
  );

  /// "Oggi" header sezione orders. 36/41 w700 LS -0.07em.
  static const TextStyle title36BoldOggi = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    fontSize: 36,
    height: 41 / 36,
    letterSpacing: -0.07 * 36,
    color: OnlistColors.white,
  );

  /// "Grazie per esserti registrato!" schermata 04. 32/32 w500.
  static const TextStyle title32Medium = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w500,
    fontSize: 32,
    height: 1.0,
    color: OnlistColors.white,
  );

  /// "Torna indietro" in club detail/booking. 32/32 w300 LS -0.03em.
  static const TextStyle title32Light = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w300,
    fontSize: 32,
    height: 1.0,
    letterSpacing: -0.03 * 32,
    color: OnlistColors.white,
  );

  /// "Prossime serate" / nome card serata. 32/37 w700 LS -0.08em.
  static const TextStyle title32Bold = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 37 / 32,
    letterSpacing: -0.08 * 32,
    color: OnlistColors.white,
  );

  /// "Data" titolo card notifica 16. 28/32 w400 LS -0.1em.
  static const TextStyle title28Regular = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 28,
    height: 32 / 28,
    letterSpacing: -0.1 * 28,
    color: OnlistColors.white,
  );

  /// "Inserisci la tua posizione" schermata 06. 20/20 w500.
  static const TextStyle title20Medium = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w500,
    fontSize: 20,
    height: 1.0,
    color: OnlistColors.white,
  );

  /// "RISERVA IL TUO POSTO ORA" / "ANNULLA PREVENDITA". 20/23 w700 LS -0.07em.
  static const TextStyle button20Bold = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 23 / 20,
    letterSpacing: -0.07 * 20,
    color: OnlistColors.white,
  );

  /// "Buon divertimento!" schermata 15. 20/20 w300 LS -0.07em.
  static const TextStyle body20Light = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w300,
    fontSize: 20,
    height: 1.0,
    letterSpacing: -0.07 * 20,
    color: OnlistColors.white,
  );

  // ── Card "Ticket" ───────────────────────────────────────────────────────

  /// Etichetta "Ticket x 1" / "Ticket Normale" lista (sm). 39.52/45 w400 LS -0.1em.
  static const TextStyle ticketLabel = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 39.52,
    height: 45 / 39.52,
    letterSpacing: -0.1 * 39.52,
    color: OnlistColors.white,
  );

  /// "Ticket" titolo card dettaglio (lg). 50/57 w400 LS -0.1em.
  static const TextStyle ticketTitleLg = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 50,
    height: 57 / 50,
    letterSpacing: -0.1 * 50,
    color: OnlistColors.white,
  );

  /// "Normale"/"Vip" sottotitolo lista. 24/29 w300 (Helvetica Light) LS -0.06em.
  static const TextStyle ticketSubtitleSm = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w300,
    fontSize: 24,
    height: 29 / 24,
    letterSpacing: -0.06 * 24,
    color: OnlistColors.white,
  );

  /// "Normale"/"Vip" sottotitolo dettaglio. 48/59 w300 LS -0.06em.
  static const TextStyle ticketSubtitleLg = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w300,
    fontSize: 48,
    height: 59 / 48,
    letterSpacing: -0.06 * 48,
    color: OnlistColors.white,
  );

  /// "Ticket normale" sottotitolo card sintetica carrello/orders. 20/25 w300 LS -0.06em.
  static const TextStyle ticketSubtitleXs = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w300,
    fontSize: 20,
    height: 25 / 20,
    letterSpacing: -0.06 * 20,
    color: OnlistColors.white,
  );

  /// Prezzo grande "10€"/"25€" lista. 96/110 w400 LS -0.08em.
  static const TextStyle price96 = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 96,
    height: 110 / 96,
    letterSpacing: -0.08 * 96,
    color: OnlistColors.white,
  );

  /// Prezzo "10€"/"25€" dettaglio singolo ticket. 192/221 w400 LS -0.08em.
  static const TextStyle price192 = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 192,
    height: 221 / 192,
    letterSpacing: -0.08 * 192,
    color: OnlistColors.white,
  );

  // ── Body / labels ───────────────────────────────────────────────────────

  /// "Entrata valida..." / "+ 2 drink omaggio" dettaglio (24). 24/28 w400 LS -0.1em.
  static const TextStyle body24Regular = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 24,
    height: 28 / 24,
    letterSpacing: -0.1 * 24,
    color: OnlistColors.white,
  );

  /// Label CTA bottoni (AGGIUNGI AL CARRELLO ecc.). 24/28 w700 LS -0.07em.
  static const TextStyle button24Bold = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 28 / 24,
    letterSpacing: -0.07 * 24,
    color: OnlistColors.white,
  );

  /// "+ 2 drink omaggio" card lista. 16/18 w400 LS -0.1em.
  static const TextStyle body16Tight = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 18 / 16,
    letterSpacing: -0.1 * 16,
    color: OnlistColors.white,
  );

  /// "Trap - Techno House" / "House - Afro House". 16/18 w700.
  static const TextStyle body16Bold = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 18 / 16,
    color: OnlistColors.white,
  );

  /// Form fields underline (Nome, Cognome, Email, Password). 22/22 w700.
  static const TextStyle formLabel22 = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.0,
    color: OnlistColors.white,
  );

  /// Bottoni piccoli secondari (Accedi/Registrati/Entra). 16/22 w700.
  static const TextStyle button16Bold = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 22 / 16,
    color: OnlistColors.black,
  );

  /// "Visualizza QR Code" / "Chiudi QR Code". 15/15 w400 LS -0.1em.
  static const TextStyle link15 = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.0,
    letterSpacing: -0.1 * 15,
    color: OnlistColors.white,
  );

  /// Date piccole sotto card serata. 13/13 w400.
  static const TextStyle caption13 = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.0,
    color: OnlistColors.white,
  );

  /// "A BREVE TI ARRIVERÀ UN EMAIL DI CONFERMA". 12/12 w500.
  static const TextStyle caption12Medium = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.0,
    color: OnlistColors.white,
  );

  /// Etichette card serata (Milano (MI) / 23:00 - 04:00). 12/12 w400.
  static const TextStyle caption12 = TextStyle(
    fontFamily: _family,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.0,
    color: OnlistColors.white,
  );
}
