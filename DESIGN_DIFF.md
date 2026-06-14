# DESIGN_DIFF — Allineamento app ↔ Figma

> **Ciclo corrente (giugno 2026):** allineamento schermata per schermata con approvazione
> esplicita, usando le fonti `docs/figma_screen/attuale_2/` (stato attuale), `analisi/*.png`
> (dimensioni), `analisi/*.css` (valori), `off/` (riferimento finale).
> L'appendice "Fase 0" più in basso è il lavoro precedente (metodologia `all-layers-mvp.txt`).

Legenda stato: ⬜ da fare · 🔎 in analisi · ✅ approvata/completata · ⏭️ saltata

| # | Schermata | File Flutter | Stato | Commit |
|---|---|---|---|---|
| 1 | Splash | splash_screen.dart | ✅ completata | `55139f8` |
| 2 | Autenticazione | authentication_screen.dart | ✅ completata | `9c29441` |
| 3 | Registrazione | sign_up_screen.dart | ⬜ da fare | — |
| 4 | Conferma email | verification_screen.dart | ✅ completata | `392bcbf` |
| 5 | Concedi posizione | location_permission_screen.dart | ✅ completata | `2bd8063` |
| 6 | Ricerca città | location_manual_screen.dart | ⬜ da fare | — |
| 7 | Home | home_screen.dart | ⬜ da fare | — |
| 8 | Carrello (vuoto+pieno) | cart_screen.dart | ⬜ da fare | — |
| 9 | Disco singola | club_detail_screen.dart | ⬜ da fare | — |
| 10 | Selezione ticket | booking_screen.dart | ⬜ da fare | — |
| 11 | Ordine effettuato | payment_success_screen.dart | ⬜ da fare | — |
| 12 | Notifiche | notifications_screen.dart | ⬜ da fare | — |
| 13 | Riepilogo ordini | orders_screen.dart | ⬜ da fare | — |
| 14 | Prevendita acquistata (QR) | prevendita_detail_screen.dart | ⬜ da fare | — |
| 15 | Pop-up info serata | event_info_popup_screen.dart | ⬜ da fare | — |
| 16 | Account / Profilo | profile_screen.dart | ⬜ da fare | — |

### #1 Splash (commit `55139f8`)
- Anello freccia: bordo `4*scaleX` → `1.8*scaleX` (tratto sottile come `off/01`); icona `28`→`26`.
- Già allineati: canvas 393×852, logo 311×311, freccia 48, gradiente radiale `#0107D6`→nero alto-sinistra.

### #2 Autenticazione
- **Campi Email/Password**: erano alti ~33px col testo centrato nel vuoto → `contentPadding` `top8/bottom6`→`top2/bottom2` + `textAlignVertical: bottom` (testo appoggiato sulla riga, label vicina alla riga come Figma).
- Spazio Email→Password `SizedBox(28)`→`40` (ritmo label→label ≈ 87px del Figma).
- Margine laterale: `padding fisso 32` → `R.w(9.9)` (Figma left 39/393 ≈ 9.9%, ora responsive).
- Logo Google `22`→`24` (coerente con icona Apple e CSS 24.21).
- Icona occhio mostra/nascondi password: **mantenuta** su richiesta (utilità > fedeltà; il Figma non la mostra ma è un elemento funzionale).
- Già corretti nel codice (verificato, nessun override nel tema): titolo "Accedi" w400, testo social `19.48/w500/grigio` → confermato su localhost dopo rebuild.

### #5 Concedi posizione
- Testo italiano mantenuto (l'inglese del Figma è solo placeholder).
- **Testo in basso mantenuto** ("La tua posizione è protetta…") con font corretto: `HelveticaNeue` 12 + interlinea `16/12` (come CSS SF Pro Text → HelveticaNeue).
- **Titolo non più schiacciato**: usava `title36Bold.copyWith(fontSize: 24)` che portava `letterSpacing -2.88` (per 36px) comprimendo il testo a 24px → ora `24/w700/line 28/letter-spacing +0.87` come CSS. Rimosso import `onlist_text_styles` non più usato.

### #4 Conferma email
- **Linea bianca sul bordo rimossa**: lo Scaffold non impostava `backgroundColor` (default bianco) → aggiunto `backgroundColor: black` + gradiente in `Container` a piena pagina (`width/height: infinity`).
- **Bottone "Accedi" più in basso**: `Spacer` con pesi `5 / 2 / 1` (top / pre-Accedi / pre-Torna) → Accedi a ~74% come Figma (`top 632/852`), responsive e senza overflow.
- Font bottone invariato (`button16Bold` = HelveticaNeue Bold 16, come login e CSS).

#### #2 rifiniture (verifica su localhost)
- **Bottoni social allineati a sinistra**: `ElevatedButton.icon` ora con `alignment: centerLeft` + `padding left 14` (Figma: icona left 13.9, testo left 49). Prima erano centrati.
- **Campi Email/Password**: `contentPadding` `top2/bottom2` → `top6/bottom4` + `textAlignVertical.bottom`: il testo digitato si appoggia sulla riga staccato dalla label (niente sovrapposizioni mentre si scrive).
- **Distribuzione verticale resa identica al Figma**: il layout era "schiacciato" in alto (SizedBox fissi 72/60/32 in scroll top-aligned). Ora i tre vuoti grandi sono proporzionali: sopra il titolo `R.h(13.5)` (Figma ~117/852), tra Registrati e social `R.h(14)` (social ~587/852), sotto i social `R.h(17)` (~149/852). Distanze come l'ufficiale su qualsiasi altezza.

---

# Appendice — Fase 0 (lavoro precedente, riferimento)

> Confronto schermata per schermata tra **stato attuale**, **codice Flutter** e **Figma**
> (`docs/figma_screen/all-layers-mvp.txt` + PNG in `docs/figma_screen/off/`).

---

## 0. Premesse che cambiano l'inquadramento (leggere prima)

1. **Il design system è già implementato nel codice.**
   - I font **HelveticaNeue** (pesi 300/400/500/700) sono **già bundlizzati** in
     [assets/fonts/](assets/fonts/) e dichiarati nel `pubspec.yaml`.
   - I token [onlist_colors.dart](lib/theme/onlist_colors.dart) e
     [onlist_text_styles.dart](lib/theme/onlist_text_styles.dart) sono **già mappati 1:1**
     sui valori del CSS Figma (colori, font-size, weight, line-height, letter-spacing).
   - Esiste un sistema responsive ([responsive.dart](lib/core/utils/responsive.dart) → `R.sp/R.w/R.h`,
     [size_utils.dart](lib/core/utils/size_utils.dart) → `.h/.fSize`) usato in tutte le schermate di Fase 0.

2. **Gli screenshot dell'.ipa sembrano PRECEDERE il codice attuale.**
   Esempio lampante: `home.jpeg` mostra "Posizione Attuale / Rimuovi GPS" e una singola card,
   mentre il codice attuale renderizza già il layout "07-aggiornato" (hero + pill "Il tuo club
   preferito" + sezione "Club consigliati"). Quindi l'asse **azionabile** del confronto è
   **CODICE ↔ Figma**; lo screenshot è usato come riferimento e segnalato quando "vecchio".

3. **Decisioni concordate** (le tue risposte): font → Helvetica Neue (già fatto);
   Home target → `07-aggiornato`; `popup_serata` e `ordine_effettuato` **esclusi** dalla Fase 0;
   profondità → **layout identico al Figma** (anche strutturale).

4. **Solo 3 schermate usano ancora `GoogleFonts.inter`** (`event_detail`, `table_map`,
   `tavolo_detail`) e **nessuna è nel set di Fase 0**.

**Legenda severità:** 🔴 critico (rompe l'aspetto) · 🟡 medio (visibile) · ⚪ basso (rifinitura)
**Legenda confidenza:** ✅ verificato sul CSS · 🔎 da ri-verificare sul CSS in Fase 1 (sezione non ancora letta integralmente)

---

## 1. Login — `login.jpeg`
CSS: `Start` (L1186–1674) · PNG: `02 - Autenticazione` · Codice: [authentication_screen.dart](lib/presentation/authentication_screen/authentication_screen.dart) · **Stato: ✅ COMPLETATA** (1.1 social 16→19.48 · 1.3 underline 2→3 · 1.4/1.5 gap →22 · 1.2/1.6/1.7 non toccati per scelta) — `flutter analyze` pulito

Già allineati: titolo "Accedi" 40/w400 (`display40Regular`), label campi 22/w700 (`formLabel22`),
bottoni bianchi 150×40 r10, social 47h r11, sfondo radiale onboarding.

| # | Cosa | Attuale (codice) | Figma (CSS) | Sev | Conf |
|---|------|------------------|-------------|-----|------|
| 1.1 | Label social ("Continua con…") font-size | `16` | `19.48px` | 🟡 | ✅ |
| 1.2 | Font label social | `HelveticaNeue` | Apple→`SF Pro` 510, Google→`Roboto` 500 (font nativi brand) | ⚪ | ✅ |
| 1.3 | Sottolineatura campi | `BorderSide width: 2` | Rectangle `height 3px`, `radius 1.5` | ⚪ | ✅ |
| 1.4 | Spaziatura tra "Accedi" e "Registrati" | `SizedBox(16)` | `gap: 22` | ⚪ | ✅ |
| 1.5 | Spaziatura tra Apple e Google | `SizedBox(12)` | `gap: 22` | ⚪ | ✅ |
| 1.6 | Peso label bottoni Accedi/Registrati | `w700` | `SF Compact 790` (≈w800; HelveticaNeue bundlizzato max 700) | ⚪ | ✅ |
| 1.7 | Spaziature verticali | `SizedBox` fissi (72/40/28/40/60) | non responsive → usare `R.h`/`R.sp` | ⚪ | — |

---

## 2. Home — `home.jpeg`
CSS: `Home` (L1919–2653) · PNG target: `07 - Home-aggiornato` · Codice: [home_screen.dart](lib/presentation/home_screen/home_screen.dart) · **Stato: ✅ COMPLETATA** (2.1 nome card 28→32 · 2.2 indirizzo→24/w500 · 2.3 rimosse righe orario/prezzo/generi · 2.4 toggle GPS mantenuto) — `flutter analyze` pulito

Già allineati: hero + pill "Il tuo club preferito" (gradiente + r5 + 14/w700), nome club hero 36/w700/LS-0.08,
CTA "RISERVA IL TUO POSTO ORA" (gradiente `rgba(152,152,152,.2)→rgba(30,0,255,.2)`, 20/w700/LS-0.08, h49 r10),
titolo "Club consigliati" 32/w700/LS-0.08, card consigliata 369×108 (img 165×95, PRENOTA 86×38 r6.48 ombra).

| # | Cosa | Attuale (codice) | Figma (CSS) | Sev | Conf |
|---|------|------------------|-------------|-----|------|
| 2.1 | Nome club nelle card "Club consigliati" | `28px` (h33/28) | `32px` line37 LS-0.08 (L2357) | 🟡 | ✅ |
| 2.2 | Indirizzo sotto l'hero | `R.sp(16)` w700 opacity .6 | `Helvetica Neue 500 24px` (L2155, no opacity) | 🟡 | ✅ |
| 2.3 | **Righe extra orario+prezzo+generi sotto l'hero** | presenti (3 righe con icone) | **assenti**: Figma-aggiornato mostra solo indirizzo + CTA | 🔴 STRUTT. | ✅ |
| 2.4 | **Riga "Posizione Attuale" + toggle GPS** | presente (`Usa GPS`/`Rimuovi GPS`) | **assente** dal Figma (elemento funzionale aggiunto) | 🟡 STRUTT. | ✅ |
| 2.5 | Gradiente card consigliata | `[#000,#0009FF]` stops .21/.82 orizz. | `94.97deg rgba(0,0,0,.8)→rgba(21,0,181,.8)` | ⚪ | ✅ |

> **DECISO:** 2.3 → **rimuovere** le righe orario/prezzo/generi (resta indirizzo 24/w500 + CTA, come Figma).
> 2.4 → **tenere** il toggle GPS (elemento funzionale, scostamento accettato dal Figma).

---

## 3. Dettaglio locale — `dettaglio_locale.jpeg` / `dettaglio_locale_scroll.jpeg`
CSS: `Home Disco singola` (L2654–3302) · PNG: `10 - Disco singola…(-aggiornato)` · Codice: [club_detail_screen.dart](lib/presentation/club_detail_screen/club_detail_screen.dart) · **Stato: ✅ COMPLETATA** (3.1 indirizzo→23/w500/.8 · 3.2 righe info→18/w700/.6 icona 20 · 3.3 bookmark→48 · 3.4 card serata riprogettata sul Figma Frame 351 369×132) — `flutter analyze` pulito

Già allineati: titolo club 36/w700/LS-0.08, "Torna indietro" `title32Light` (32/w300/LS-0.03), card serata gradiente `cardSummary`.

| # | Cosa | Attuale (codice) | Figma (CSS) | Sev | Conf |
|---|------|------------------|-------------|-----|------|
| 3.1 | Indirizzo | ~~`R.sp(16)` w400 opacity .6~~ → `23/w500/.8` ✅ | `Helvetica Neue 500 23px` opacity .8 (L2737) | 🟡 | ✅ fatto |
| 3.2 | Righe info | ~~`14/w400/.7` icona 16~~ → `18/w700/.6` icona 20 ✅ | `Helvetica 700 18px` op.6, icona 20 (L2757) | 🟡 | ✅ fatto |
| 3.3 | Icona bookmark | ~~`R.sp(32)`~~ → `R.sp(48)` ✅ | `48×48` (L2775) | 🟡 | ✅ fatto |
| 3.4 | Card "Prossime serate" | ~~card 140h gradiente cardSummary, locandina 130, pill bianca~~ → **riprogettata** Frame 351 ✅ | `369×132` grad `#000 28%→#000B83`, locandina 95×119, titolo 32/w700, OGGI 24, data 18, orario 13, generi 13/w700, PRENOTA 86×38 grad `#000→#000B83` r6.48 (L2968–3145) | 🟡 STRUTT. | ✅ fatto |
| 3.5 | Placeholder "Nessuna immagine disponibile" | dipende dai dati (fallback) | Figma mostra immagini | ⚪ (dato) | — |

---

## 4. Selezione ticket — `selezione_ticket.jpeg`
CSS: `Carrello - Ticket` (L3303–4218) · PNG: `11 - Carrello_Ticket` · Codice: [booking_screen.dart](lib/presentation/booking_screen/booking_screen.dart) `_buildTicketCard` · **Stato: DA FARE — quasi allineato**

CSS verificato (✅): card `#1900D8` r10, prezzo `96px`/LS-0.08, "Vip/Normale" Helvetica Light `24px`/LS-0.06, "Entrata valida…" `16px`/LS-0.1 → tutti già nei valori del codice.

| # | Cosa | Attuale (codice) | Figma (CSS) | Sev | Conf |
|---|------|------------------|-------------|-----|------|
| 4.1 | Sfondo card | `#1900D8` r10 | `#1900D8` r10 (L3366) → **già corretto** | — | ✅ |
| 4.2 | Titolo "Ticket" | `R.sp(40)` | `39.52px` line45 LS-0.1 (L3401) → usare `ticketLabel` | ⚪ | ✅ |
| 4.3 | Padding/posizioni interne card | hardcoded (`all(22)`, `SizedBox(80)`) | il Figma posiziona in assoluto; ricontrollare spacing su schermi piccoli | ⚪ | ✅ |

---

## 5. Dettaglio Ticket Normale / Vip — `ticket_normale_dettaglio.jpeg` / `ticket_vip_dettaglio.jpeg`
CSS: `Carrello - Ticket Normale` (L4219) / `Carrello - Ticket Vip` (L4733) · PNG: `12` / `13` · Codice: [booking_screen.dart](lib/presentation/booking_screen/booking_screen.dart) `_buildTicketDetailStep` · **Stato: DA FARE — già allineato**

> ✅ **Risolto.** La card **visibile** del dettaglio (Figma L4429–4503, gradiente `#000→#0015FF`) usa
> esattamente i valori del codice: "Ticket" **50px** (`ticketTitleLg`), "Normale/Vip" **48px** Helvetica Light
> (`ticketSubtitleLg`), prezzo **192px** (`price192`), "+N drink"/"Entrata valida" **24px** (`body24Regular`),
> CTA gradiente **`#1800D2 19.48% → #120099`** r10 + "AGGIUNGI AL CARRELLO" 24/w700/LS-0.07 (`primaryCTA`+`button24Bold`).
> I valori contrastanti (171.52px / 40px) appartengono a un **gruppo nascosto** (`visibility:hidden`), non alla
> card reale. **Nessuna discrepanza da correggere.**

| # | Cosa | Attuale (codice/token) | Figma (CSS) | Sev | Conf |
|---|------|------------------------|-------------|-----|------|
| 5.1 | Prezzo / titolo / sottotitolo / CTA | `price192` / `ticketTitleLg 50` / `ticketSubtitleLg 48` / `primaryCTA` | `192` / `50` / `48` / `#1800D2→#120099` (L4440–4622) | — | ✅ allineato |

---

## 6. Carrello — `carrello.jpeg`
CSS: condivide la card di `Riepilogo ticket acquistati` (L6234+) · PNG: `14 - Carrello con qualcosa` · Codice: [cart_screen.dart](lib/presentation/cart_screen/cart_screen.dart) `_buildTicketCartView` · **Stato: DA FARE — quasi allineato**

> Nota mapping: non esiste una sezione CSS "Carrello con qualcosa"; la card sintetica del carrello è lo
> **stesso componente** usato in `Riepilogo` (gradiente `#1E00FF→#020011`), che ho verificato (§7).

| # | Cosa | Attuale (codice) | Figma (CSS) | Sev | Conf |
|---|------|------------------|-------------|-----|------|
| 6.1 | Gradiente/raggio card sintetica | `cardSummary` (`#1E00FF→#020011`) r10 | `#1E00FF→#020011` r10 (L6252) → **già corretto** | — | ✅ |
| 6.2 | Token testo (Ticket xN / tipo / prezzo / +drink) | `ticketLabel`/`ticketSubtitleXs`/`price96`/`body24Regular` | corrispondono ai valori Figma della card | — | ✅ |
| 6.3 | Selettore "Quantità" | label 18/w500, valore box bianco r5 | elemento non presente nel CSS (stato "carrello pieno" non disegnato) → confronto su PNG | ⚪ | ❌ (no CSS) |

---

## 7. Prevendita / QR — `prevendita_qr.jpeg`
CSS: `Riepilogo ticket acquistati` (L6234–6783) · PNG: `18 - …qr` · Codice: [prevendita_detail_screen.dart](lib/presentation/prevendita_detail_screen/prevendita_detail_screen.dart) · **Stato: DA FARE — già allineato**

> ✅ **Verificato esatto.** Card `353×601` gradiente `#1E00FF→#020011` r10 (= `cardSummary`); pill ANNULLA
> PREVENDITA `219×35` r10 bianco **13%** (L6256–6265) → identica al codice. Token testo già corretti.

| # | Cosa | Attuale (codice) | Figma (CSS) | Sev | Conf |
|---|------|------------------|-------------|-----|------|
| 7.1 | Card + pill ANNULLA | `cardSummary` r10 · pill 219×35 r10 bianco 13% | identici (L6252/L6264) | — | ✅ |
| 7.2 | Dimensione QR | `R.width*0.62` clamp(160,238) | non quotata nel CSS; resa coerente col PNG | ⚪ | — |

---

## 8. Account — `account.jpeg` / `account_scroll.jpeg`
CSS: `Account` (L6784–7098) — **sezione povera/ambigua** · PNG: `Account.png` · Codice: [profile_screen.dart](lib/presentation/profile_screen/profile_screen.dart) · **Stato: ESCLUSA (DECISO: lascia com'è — manca fonte CSS)**

> ⚠️ La sezione CSS "Account" **non descrive i campi del profilo**: contiene un blocco `Group 362`
> con `visibility: hidden` che è in realtà un **ticket** (Ticket/10€/Normale/+2 drink). Quindi per
> l'Account i valori px esatti **non sono ricavabili dal CSS** — il riferimento è il PNG `Account.png`.
> Te lo segnalo come da istruzioni (mismatch CSS↔screen).

Codice attuale: label campo 14/w400 white60 + valore 16/w400 + underline 1px; titolo "Salvati" 26/w700/LS-0.08;
card preferito 120h con overlay gradiente + nome 24/w700; lista azioni (Riepilogo Ordini / Cambia Password / Disconnetti).

| # | Cosa | Attuale (codice) | Figma | Sev | Conf |
|---|------|------------------|-------|-----|------|
| 8.1 | Valori px campi/titoli | vedi sopra | non disponibili nel CSS (solo PNG) | 🟡 | ❌ (no CSS) |
| 8.2 | Coerenza con PNG `Account.png` | layout simile allo screenshot | confronto visivo sul PNG | ⚪ | — |

---

## 9. Notifiche — `notifiche.jpeg`
CSS: `Notifiche` (L7510–fine) · PNG: `16 - Notifiche` · Codice: [notifications_screen.dart](lib/presentation/notifications_screen/notifications_screen.dart) · **Stato: DA FARE**

Codice: label data `title28Regular` (28/w400/LS-0.1); card 66h gradiente `[bianco20%→#1E00FF 20%]` r10;
titolo notifica `ticketLabel` (39.52/w400).

> ✅ **Verificato esatto** (L7888–7995). Card `369×66` r10 gradiente `90deg rgba(255,255,255,.2)→rgba(30,0,255,.2)`
> = `[0x33FFFFFF, 0x331E00FF]`; titolo `39.52px`/LS-0.1 (`ticketLabel`); data `28px` line32/LS-0.1 (`title28Regular`).
> Il mio sospetto precedente (gradiente diverso) era un **falso positivo**: avevo letto la barra di navigazione, non la card.

| # | Cosa | Attuale (codice) | Figma (CSS) | Sev | Conf |
|---|------|------------------|-------------|-----|------|
| 9.1 | Card notifica (gradiente, h66, titolo, data) | `[0x33FFFFFF,0x331E00FF]` r10 · `ticketLabel` · `title28Regular` | identici (L7893/7905/7929) | — | ✅ allineato |

---

## Riepilogo cross-cutting
- ⚪ **Spaziature hardcoded** (`SizedBox`/`EdgeInsets` fissi non scalati) in quasi tutte le schermate:
  in Fase 1 valutare se passarle a `R.h/R.sp` dove rompono il design su schermi piccoli.
- 🟡 **Incoerenza dimensione bookmark**: home `48`, dettaglio locale `R.sp(32)` (Figma vuole `48`).
- ✅ **Colori "quasi uguali"**: `#1800D2` (`blueIntense3`) e `#1900D8` (`bluePrimary`) sono **entrambi**
  presenti nel CSS Figma (il primo nel gradiente `primaryCTA`, il secondo come brand) → nessun
  consolidamento necessario, sono usati come da Figma.

## Esito Fase 0 — verifica CSS completata al 100%
Tutte le sezioni CSS rilevanti sono state lette riga per riga. **Sintesi:**
- **Già allineate al Figma** (nessuna modifica necessaria): Selezione ticket (§4), Dettaglio ticket (§5),
  Carrello (§6), Prevendita/QR (§7), Notifiche (§9).
- **Diff reali residui (rifiniture)**: Login (§1 — label social 16→19.48, sottolineatura 2→3, gap),
  Dettaglio locale (§3 — indirizzo/orario/bookmark), Home (§2 — nome card consigliata 28→32, indirizzo).
- **Decisioni prese**: §2.3 rimuovere righe extra Home · §2.4 tenere toggle GPS · §8 Account lasciata com'è.

## Piano Fase 1 (proposto — una schermata alla volta, con tuo ok prima di ciascuna)
Schermate che richiedono interventi (le altre sono già allineate):
1. **Login** (§1): label social 16→19.48, sottolineatura 2→3px, gap bottoni/social 12/16→22.
2. **Dettaglio locale** (§3): indirizzo 16/w400/.6→23/w500/.8, riga orario 14/.7→18/w700/.6, bookmark 32→48.
3. **Home** (§2): rimuovere righe orario/prezzo/generi, indirizzo 16/w700→24/w500, nome card consigliata 28→32.

Dopo ogni schermata: `flutter analyze`, aggiornamento di questo file (Stato → COMPLETATA) e diff in revisione.
