# SCREENS_AUDIT.md — Audit allineamento UI vs Figma (branch MVP)

> **Stato**: FASE 0 — solo mappatura e rilevamento differenze. Nessuna modifica al codice.
> **Riferimento immagini**: `docs/figma_screen/off/` (17 immagini ufficiali, numerate)
> **Riferimento design system**: `.claude/CLAUDE.md` §2
> **Data scansione**: 2026-05-27

---

## 0. Note preliminari

### Anomalie sulle immagini di riferimento
- **Manca `09 - *.png`** nella cartella `/off/`. La numerazione salta da `08` a `10`. Da chiedere conferma se è una rinumerazione voluta o un file mancante.
- Le immagini `02`, `03`, `04` mostrano un titolo **"Accedi"** anche sulla schermata di registrazione (sembra un refuso del Figma — la 03 è "Registrati" come azione).

### Findings trasversali (tutte le schermate)

Differenze sistematiche che NON elenco poi sotto ogni schermata per non ripeterle:

1. **Font globale**: il codice usa **`GoogleFonts.inter`** ovunque, ma il Figma usa **Helvetica / Helvetica Neue / SF Pro / SF Compact** (cfr. CLAUDE.md §2 "Tipografia"). Cambia il look di TUTTI i testi.
2. **Sfondi schermate**: il Figma usa **gradienti radiali/lineari** definiti nel design system (`linear-gradient(180deg, #000 0%, #060037 100%)` per schermate dark, `radial-gradient(... #0107D6 0%, #000 100%)` per onboarding). Nel codice molte schermate hanno `Colors.black` puro o `Color(0xFF0000FF)` blu acceso — **nessun gradiente**.
3. **Bottom nav (SharedFooter)** — ordine icone DIVERSO dal Figma:
   - **Figma**: Home(0) | Borsa/Acquisti(1) | Carrello(2) | Campanella(3) — l'icona persona NON è nel bottom nav, è in alto a destra (CustomTopBar).
   - **Codice** ([shared_footer.dart:38-45](lib/widgets/shared_footer.dart#L38-L45)): Home(0) | Carrello(1) | Campanella(2) | **Persona(3)** — manca l'icona Borsa/Acquisti, e Persona è duplicata (è già nel CustomTopBar).
   - Conseguenza: nel Figma le schermate `17`/`18` (Riepilogo ticket) hanno la **Borsa attiva** (tab 1); nel codice quella tab non esiste e l'orders_screen passa `currentIndex: -1` (nessuna tab selezionata).
4. **Border radius schermata**: tutte le mockup Figma hanno `border-radius: 32px` sui 4 angoli dello schermo (è il rounded del mockup iPhone, non del telefono reale). Da ignorare — non è UI.
5. **Logo OnList**: in `01 - Prima pagina` è **311×311 px con border-radius 77px**. Nel codice `splash_screen` è **140×140** senza bordi (`Image.asset` semplice).
6. **Template CTA comune** (emerso da `all-layers-mvp.txt`): tutti i bottoni primari full-width del Figma — `AGGIUNGI AL CARRELLO`, `ORDINA IL TUO POSTO ORA`, `TORNA NELLA HOME`, `CONTINUA L'ORDINE` — sono **istanze dello stesso template**:
   - Dimensioni: `370×43` (alcuni `351×43`), `border-radius: 10px`
   - Gradiente: `linear-gradient(90deg, #1800D2 19.48%, #120099 100%)` (o variante con stop `#1900D8 38.86%` al centro)
   - Testo: `Helvetica 24/28 w700 letter-spacing -0.07em`, colore `#FFFFFF`
   - Conviene crearli come unico componente condiviso (es. `widgets/onlist_primary_button.dart`) per non duplicare.
7. **Card "Carrello/Riepilogo" — due varianti di gradiente**:
   - **Card grande singolo ticket** (schermate 12, 13): `linear-gradient(180deg, #000000 0%, #0015FF 100%)`, `370×527 border-radius 10`.
   - **Card sintetica** (schermate 14, 17, 18): `linear-gradient(180deg, #1E00FF 0%, #020011 100%)`, altezza variabile (175, 222, 601).
   - Nel codice spesso si vede `Color(0xFF1900D8)` solido — è un colore vicino ma NON il gradiente del Figma.

---

## 1. Abbinamento schermate (Figma ↔ Dart)

| # | Nome Figma | File Dart | Funzione | Stato |
|---|---|---|---|---|
| 01 | Prima pagina | [splash_screen.dart](lib/presentation/splash_screen/splash_screen.dart) | Entry point, logo OnList + freccia | [ ] da fare |
| 02 | Autenticazione | [authentication_screen.dart](lib/presentation/authentication_screen/authentication_screen.dart) | Login email/pwd + Apple/Google | [ ] da fare |
| 03 | Registrazione | [sign_up_screen.dart](lib/presentation/sign_up_screen/sign_up_screen.dart) | Form Nome/Cognome/DoB/Email/Pwd | [ ] da fare |
| 04 | Messaggio Conferma Email | [verification_screen.dart](lib/presentation/verification_screen/verification_screen.dart) | "Grazie per esserti registrato!" | [ ] da fare |
| 05 | Concedi Posizione | [location_permission_screen.dart](lib/presentation/location_permission_screen/location_permission_screen.dart) | Permesso GPS | [ ] da fare |
| 06 | Ricerca Città | [location_manual_screen.dart](lib/presentation/location_manual_screen/location_manual_screen.dart) | Inserimento città/CAP manuale | [ ] da fare |
| 07 | Home | [home_screen.dart](lib/presentation/home_screen/home_screen.dart) | Locale vicino + prossime serate | [ ] da fare |
| 08 | Carrello vuoto | [cart_screen.dart](lib/presentation/cart_screen/cart_screen.dart) (stato vuoto) | Carrello senza articoli | [ ] da fare |
| 09 | *(manca immagine)* | — | — | — |
| 10 | Disco singola (ricerca) | [club_detail_screen.dart](lib/presentation/club_detail_screen/club_detail_screen.dart) + [event_detail_club_screen.dart](lib/presentation/event_detail_club_screen/event_detail_club_screen.dart) | Scheda club + prossime serate | [ ] da fare |
| 11 | Carrello_Ticket (lista) | [booking_screen.dart](lib/presentation/booking_screen/booking_screen.dart) step `ticketList` | Lista prevendite (Normale/VIP) | [ ] da fare |
| 12 | Carrello_Ticket Normale | [booking_screen.dart](lib/presentation/booking_screen/booking_screen.dart) (variante singolo ticket) | Dettaglio ticket Normale 10€ | [ ] da fare |
| 13 | Carrello_TicketVip | [booking_screen.dart](lib/presentation/booking_screen/booking_screen.dart) (variante singolo ticket) | Dettaglio ticket VIP 25€ | [ ] da fare |
| 14 | Carrello con qualcosa | [cart_screen.dart](lib/presentation/cart_screen/cart_screen.dart) (stato pieno, ticket) | Riepilogo ordine ticket + paga | [ ] da fare |
| 15 | Ordine Effettuato | [payment_success_screen.dart](lib/presentation/payment_success_screen/payment_success_screen.dart) | Conferma post-pagamento | [ ] da fare |
| 16 | Notifiche | [notifications_screen.dart](lib/presentation/notifications_screen/notifications_screen.dart) | Lista notifiche | [ ] da fare |
| 17 | Riepilogo ticket acquistati | [orders_screen.dart](lib/presentation/orders_screen/orders_screen.dart) | Lista ordini (tab Prevendite) | [ ] da fare |
| 18 | Riepilogo ticket acquistati-QR | [prevendita_detail_screen.dart](lib/presentation/prevendita_detail_screen/prevendita_detail_screen.dart) | Dettaglio prevendita con QR | [ ] da fare |

### Schermate Dart SENZA corrispondenza Figma in `/off/`
Le segnalo per discussione (forse il design non è stato fatto o sta in altra cartella).

| File | Cosa fa | Note |
|---|---|---|
| [main_layout_screen.dart](lib/presentation/main_layout_screen/main_layout_screen.dart) | Shell con bottom nav | Probabile sostituto di SharedFooter — verificare se ancora usato |
| [nearby_clubs_screen.dart](lib/presentation/nearby_clubs_screen/nearby_clubs_screen.dart) | Ricerca/lista locali vicini | Cfr. `docs/figma_screen/ricerca_locali.PNG` (FUORI da `/off/`) |
| [profile_screen.dart](lib/presentation/profile_screen/profile_screen.dart) | Dati utente / logout | Cfr. `docs/figma_screen/Account.png` (FUORI da `/off/`) |
| [complete_profile_screen.dart](lib/presentation/complete_profile_screen/complete_profile_screen.dart) | Dati mancanti post-OAuth | Nessun design fornito |
| [verification_failure_screen.dart](lib/presentation/verification_failure_screen/verification_failure_screen.dart) | Fallback verifica fallita | Nessun design fornito |
| [event_detail_screen.dart](lib/presentation/event_detail_screen/event_detail_screen.dart) | — | **Probabile codice morto** (cfr. `lib/presentation/README.md`) |
| [table_map_screen.dart](lib/presentation/table_map_screen/table_map_screen.dart) | Piantina tavoli | **Probabile codice morto** + cfr. `docs/figma_screen/Ordine (Piantina tavolo).png` FUORI da `/off/` |
| [tavolo_detail_screen.dart](lib/presentation/tavolo_detail_screen/tavolo_detail_screen.dart) | Dettaglio tavolo prenotato | Cfr. `docs/figma_screen/Notifiche TAVOLO.png` FUORI da `/off/` |

### Immagini Figma in `/docs/figma_screen/` FUORI da `/off/` (non auditate qui)
`Account.png`, `Home 2.5 Info Disco + Serata + animazione per preferiti.png`, `home_no_club.PNG`, `miglioramento_grafica_home.png`, `Notifiche DETTAGLIO.png`, `Notifiche TAVOLO.png`, `Notifiche x tavolo.png`, `Notifiche.png`, `Ordina Tavolo Prenotazione BERE.png`, `Ordine (Piantina tavolo).png`, `ricerca_locali.PNG`, `Riconosci posizione tramite gps*.png`, `Riconosci posizione.png` — **non li uso come fonte ufficiale**, ma se vanno considerati segnalalo.

### Schermate trovate dentro `all-layers-mvp.txt` (ma NON tra le 17 immagini)
Leggendo il file CSS completo, ho trovato definizioni di layout per due schermate che **non hanno PNG corrispondente** in `/off/`:

- **`Account`** (line ~6784 del file): è la schermata profilo. Sfondo gradiente standard. In fondo trovo un `Group 363` con form fields **Nome / Cognome / Data di nascita / Email** (Helvetica Neue 16/22 w400, underline 315×3px bianco) + sezione `"Salvati"` (Helvetica 28/32 w400 -0.1em) con card club preferiti `315×108` gradiente `#0009FF → #000599 81.73%` border-radius 10, testi "The Club" / "Amnesia Club" Helvetica 32/37 w700 -0.08em con text-shadow. **Corrisponde verosimilmente a `profile_screen.dart` + è il design ufficiale "Account.png"**.
- **`Ordine x tavolo`** (line ~7544): contiene un bottone full-width `"CONTINUA L'ORDINE"` con stesso template CTA. È il flusso prenotazione tavolo (corrisponde a `Ordina Tavolo Prenotazione BERE.png` FUORI da `/off/`). Non ho file Dart che lo gestisca univocamente — `booking_screen.dart` lo step `tableConfig` è il candidato più vicino.

---

## 2. Differenze rilevate per schermata

> Per ogni schermata elenco SOLO le differenze rispetto al Figma corrispondente.
> Le differenze trasversali (font, gradienti, bottom nav) le ho già enumerate in §0.

---

### 01 — Prima pagina ↔ `splash_screen.dart`

**Differenze:**
- **Sfondo**: codice usa `Color(0xFF0000FF)` (blu puro) — Figma vuole gradiente radiale `radial-gradient(98.88% at 0% 1.12%, #0009FF 0%, #000 100%)`.
- **Logo**: codice `140×140` `BoxFit.contain` su `Image.asset` — Figma `311×311` con `border-radius: 77px`.
- **Freccia**: codice `Icons.arrow_upward` 22px in cerchio 44×44 con bordo 1.5 — Figma `Arrow down-circle` 48×48 ruotata di -180° con bordo 4px (lo stile è "frecciona dentro un cerchio outline").
- **Posizione**: codice ha logo + freccia centrati verticalmente con `MainAxisAlignment.center` + 48px gap — Figma li mette a `top: 270` (logo) e `top: 557` (freccia), quindi logo molto più in basso del centro.

---

### 02 — Autenticazione ↔ `authentication_screen.dart`

**Differenze:**
- **Sfondo**: `Color(0xFF0000FF)` vs gradiente radiale `radial-gradient(98.42% at 3.05% 1.58%, #0107D6 0%, #000 100%)`.
- **Titolo "Accedi"**: codice `36px / w800` con Inter — Figma `40px / w400` Helvetica Neue.
- **Bottoni "Accedi"/"Registrati"**: nel codice sono **in fila** (`Row` orizzontale) con larghezza 130 ciascuno — nel Figma sono **uno sopra l'altro** (column), `150×40` con `border-radius: 10px` (codice usa 30 = pill).
- **Bottoni social — radius**: codice `BorderRadius.circular(30)` (pill) — Figma `border-radius: 11px` (più squadrati). Altezza codice 52, Figma 47.
- **"Continua con Apple"/"Continua con Google" — colore testo**: Figma usa `rgba(0,0,0,0.74)` — codice usa `Colors.white` per Apple e `Colors.black87` per Google. Apple in Figma ha sfondo bianco e testo nero, codice ha sfondo nero e testo bianco (invertito!).
- **Logo Google**: codice usa un `CustomPainter` artigianale (vedi `_GoogleLogoPainter`) — il rendering è sicuramente diverso dal logo Google ufficiale del Figma.
- **Bottone "Accedi come Staff"**: presente nel codice ([authentication_screen.dart:152-159](lib/presentation/authentication_screen/authentication_screen.dart#L152-L159)), **NON presente nel Figma**.
- **Underline TextField**: spessore 1.5px nel codice, nel Figma è 3px con `border-radius: 1.5px`.

---

### 03 — Registrazione ↔ `sign_up_screen.dart`

**Differenze:**
- **Sfondo**: `Color(0xFF0000FF)` vs gradiente radiale.
- **Titolo nel codice è "Registrati"**, nel Figma è "Accedi" (probabile refuso del Figma — segnalo ma non considero un errore lato codice).
- **Campo Telefono**: il codice ha un campo `InternationalPhoneNumberInput` con selettore paese ([sign_up_screen.dart:171-223](lib/presentation/sign_up_screen/sign_up_screen.dart#L171-L223)), **NON presente nel Figma**. Da capire se è un'aggiunta voluta non riflessa nel design o un campo da nascondere fino al redesign.
- **Bottone "Registrati"**: codice `Border radius 30` (pill) — Figma `border-radius: 10px`, dimensioni 150×40.
- **Link "Hai già un account? Accedi"**: presente nel codice, NON presente nel Figma.
- **"Utente maggiorenne/minorenne" indicator**: presente nel codice ([sign_up_screen.dart:123-136](lib/presentation/sign_up_screen/sign_up_screen.dart#L123-L136)), NON nel Figma.

---

### 04 — Messaggio Conferma Email ↔ `verification_screen.dart`

**Differenze:**
- **Sfondo**: `Color(0xFF0000FF)` vs gradiente radiale.
- **Titolo "Grazie\nper esserti registrato!"**: codice `32px / w800` Inter — Figma `32px / w500` Helvetica Neue, `text-align: center`. La weight è molto diversa (extrabold vs medium).
- **Sottotitolo "A BREVE TI ARRIVERÀ UN EMAIL DI CONFERMA"**: codice `12px / w600 / letterSpacing 0.5` — Figma `12px / w500 / 0` letter-spacing.
- **Link "Non hai ricevuto l'email? Clicca qui"**: presente nel codice, **NON nel Figma**.
- **Link "Torna al login"** in fondo: presente nel codice, **NON nel Figma**.
- **Bottone "Accedi"**: codice `width 160 height 48 borderRadius 30` (pill nero) — Figma `150×40 border-radius 10px` (rettangolo arrotondato bianco con testo nero).
- **Colore bottone**: codice `Colors.black` su sfondo blu — Figma sfondo `#FFFFFF` con testo `#000000`. INVERTITO.

---

### 05 — Concedi Posizione ↔ `location_permission_screen.dart`

**Differenze fondamentali:**
- Il **Figma mostra un alert di sistema iOS** (popup bianco sovrapposto a uno sfondo con map preview, switcher "Precise: On", e 3 opzioni "Allow Once / Allow While Using the App / Don't Allow"). Quello è il flow nativo iOS.
- Il **codice ha una schermata full-screen custom** con icona, titolo "Abilita la posizione precisa", testo, e due bottoni "Apri Impostazioni" / "Ricordamelo più tardi".

**Le due UI sono concettualmente diverse**: il Figma è solo il MOMENT del prompt di sistema, il codice è una pre-permission rationale screen (best practice). Da decidere se vuoi che la schermata custom sparisca a favore solo del prompt nativo, o se è ok mantenere entrambe (rationale prima → prompt dopo).

Differenze "estetiche" della schermata custom:
- Sfondo `Color(0xFF0000FF)` vs gradiente design system.
- Bottoni `borderRadius 30` (pill) vs `16` del design Figma (`Controls/Buttons/Primary`).
- Testo legale `"La tua posizione è protetta..."` con icona lucchetto — non presente nel Figma.

---

### 06 — Ricerca Città ↔ `location_manual_screen.dart`

**Differenze:**
- **Sfondo**: `Color(0xFF0000FF)` vs gradiente lineare `168.55deg #0107D6 → #000`.
- **Card campi**: codice usa `Color(0xFF0A0066)` per la card — Figma usa gradiente `linear-gradient(180deg, #000 0%, #0006CA 100%)`.
- **Campo "Cap"**: nel Figma è VISIBILE (sotto "Città"). Nel codice è **commentato fuori** ([location_manual_screen.dart:147-178](lib/presentation/location_manual_screen/location_manual_screen.dart#L147-L178)) con commento "Nascosto graficamente come richiesto". Da chiarire: è una richiesta tua già passata? Lo riallineo al Figma o lascio nascosto?
- **Bottone "Entra"**: codice `160×48 borderRadius 30` nero — Figma `150×40 border-radius 10px` bianco con testo nero.
- **Suggestion list**: presente nel codice (autocomplete città), **non nel Figma** — sembra un'aggiunta funzionale opportuna, da non rimuovere.

---

### 07 — Home ↔ `home_screen.dart`

**Differenze:**
- **Sfondo**: `Colors.black` puro vs gradiente `linear-gradient(180deg, #000 0.82%, #060037 100%)`.
- **Top bar (CustomTopBar)**: in Figma c'è il logo OnList SCRITTA (`onlistscritta`, 325×135 px, posizionato `top: 0` `left: 34`) — nel codice è un'icona generica più piccola (`height: 65`).
- **Pill "Il tuo club preferito"**: presente in Figma (sopra l'hero image, gradiente da nero a blu trasparente, `135×22`, font Helvetica 14/w700) — **completamente assente nel codice**. È quello che dovrebbe distinguere il club "preferito" mostrato dalla home.
- **Bottone "RISERVA IL TUO POSTO ORA"**: presente in Figma posizionato a centro schermo (`368×49` con gradiente `90deg rgba(152,152,152,0.2) 0% → rgba(30,0,255,0.2) 100%`). **NON presente nella home del codice** — il bottone "RISERVA IL TUO POSTO ORA" è nella `club_detail_screen`, non in home.
- **Sezione "Posizione" / chip GPS**: il codice mostra una riga con `state.locationSourceLabel` + chip "Usa GPS / Rimuovi GPS" ([home_screen.dart:248-340](lib/presentation/home_screen/home_screen.dart#L248-L340)) — **non nel Figma**.
- **Card prossime serate**: Figma ha 2 card di esempio ("The Club" e "Gatto Pardo") con gradiente `94.97deg rgba(0,0,0,0.8) 1.37% → rgba(21,0,181,0.8) 100%` — il codice ha una "prominent card" prima e poi "event card" successive con gradienti diversi (`#000000 → #0009FF`). I gradienti non corrispondono esattamente.
- **Etichetta "OGGI"** sulla prima card Figma: `24px Helvetica w700 letterSpacing -0.08em` — codice usa `22.22px Inter w700` (size leggermente diversa).
- **Pillola data "Dom 19 Apr"**: in Figma c'è una `Rectangle 188 / 189` con sfondo `rgba(0,42,255,0.2) opacity 0.3` dietro alla data. Nel codice non vedo la pillola di sfondo.

---

### 08 — Carrello vuoto ↔ `cart_screen.dart` (stato vuoto)

**Differenze:**
- **Sfondo**: `Colors.black` vs gradiente `linear-gradient(180deg, #000 0%, #060037 100%)`.
- **Figma è quasi completamente vuoto** (solo logo top, "Torna indietro", bottom nav). Codice mostra invece **un'icona shopping_cart grigia + "Il carrello è vuoto" + sottotitolo** ([cart_screen.dart:229-260](lib/presentation/cart_screen/cart_screen.dart#L229-L260)). Da decidere se l'empty state custom va tenuto (è UX migliore del Figma) o reso minimal come da Figma.
- **Tab attiva**: Figma evidenzia il **carrello (3°)** con highlight `rgba(255,255,255,0.31)` sotto l'icona — codice usa `currentIndex: 1` (che nel codice è il carrello, ma vedi finding §0.3 sulla discrepanza ordine icone).

---

### 10 — Disco singola che trovi con ricerca ↔ `club_detail_screen.dart`

**Differenze:**
- **Sfondo**: `Color(0xFF0D0D0D)` vs gradiente `linear-gradient(180deg, #000 0%, #060037 100%)`.
- **"Torna indietro"**: nel Figma c'è la riga `← Torna indietro` con freccia + testo `32px Helvetica Neue w300 letterSpacing -0.03em` subito sotto il top bar — il codice **non ha questa riga in club_detail** (c'è solo la navigation del top bar).
- **Hero image**: in Figma è `373.97×216.84` con border-radius 10 a `top: 154` — codice è full-width altezza 217 con padding 10. Dimensioni e posizioni leggermente diverse.
- **Bookmark icon**: in Figma è un'icona da 48×48 outline 4px posizionata a `top: 393 left: 326` (sopra/sotto il titolo) — codice è `36×36` in `Color(0x55000000)` con icona 20px ANGOLO IN ALTO A DESTRA DELL'HERO.
- **Riga "Orario - Prezzo"**: Figma mostra `🕐 22:00 - 04:00` font Helvetica 18 w700 opacity 0.6, e (nascosto) `€€€€€` — codice usa Inter 14 w400 opacity 0.7 più piccoli.
- **Riga "Trap - Techno House"**: Figma `16 Helvetica w700 opacity 0.6` — codice `14 Inter w400 opacity 0.7`.
- **Sezioni "Come arrivare / Recensioni / Trasporti"**: **NON presenti nel Figma**, sono aggiunte nel codice. Da chiarire se sono volute o vanno rimosse.
- **Card "Prossime serate"**: Figma ha UNA SOLA card con layout specifico ("Spring Party" + "OGGI" + "Domenica 19 Aprile" + "23:00 - 04:00" + "House - Afro House" + bottone "PRENOTA" 86×38). Il codice usa `_SerataCard` con un layout MOLTO diverso (immagine 72×88 a sinistra, info compatte, prezzo + bottone "Prenota" piccolo). Sono due design completamente diversi.

---

### 11 — Carrello_Ticket (lista) ↔ `booking_screen.dart` step `ticketList`

**Differenze (px-perfect da `all-layers-mvp.txt`):**
- **Sfondo schermata**: codice `Colors.black` — Figma `linear-gradient(180deg, #000000 0%, #060037 100%)`.
- **Card ticket** (Normale e VIP, due card affiancate verticalmente):
  - Sfondo Figma `#1900D8` (codice già OK), border-radius `10px` (OK).
  - Ciascuna card occupa metà schermo verticalmente con la stessa struttura.
- **Layout interno card**:
  - Titolo `"Ticket"`: Helvetica `39.52/45 w400 letter-spacing -0.1em`, posizione `left:29 top:171` (Normale) / `left:254 top:171` (Vip).
  - Sottotitolo `"Normale"` / `"Vip"`: **Helvetica Light** `24/29 w400 letter-spacing -0.06em`. Codice usa Inter `w300`.
  - Prezzo grande `"10€"` / `"25€"`: Helvetica `96/110 w400 letter-spacing -0.08em` (codice fa già 96, OK).
  - Descrizione `"+ 2 drink omaggio"` (Normale): Helvetica `16/18 w400 letter-spacing -0.1em`, `left:29 top:444`.
  - Descrizione VIP `"+ 2 drink omaggio\n+ Salta fila\n+ Ticket guarda roba amaggio"` (sic): stesso stile, `text-align: right` per la VIP.
  - `"Entrata valida per questo ticket entro le 00:00 am"`: Helvetica `16/18 w400 letter-spacing -0.1em`, posizione bassa.
- **Bottone "PRENOTA"** dentro la card: `161×68` (non 86×38 come avevo scritto prima), gradiente `linear-gradient(180deg, #000000 0%, #201064 100%)` (verticale, non orizzontale!), border-radius `10`. Testo Helvetica `24/28 w700 letter-spacing -0.1em`.
  → Codice usa `133×58` con gradiente orizzontale `#1500B3 → #201064` (incompleto). **Direzione gradiente diversa e mancano i 28px di altezza**.
- **"Torna indietro"** top bar: codice OK (presente). Stile Figma: Helvetica Neue `32/32 w300 letter-spacing -0.03em` (testo molto grande e leggero). Codice usa Inter 16 w500 (decisamente più piccolo).

---

### 12 — Carrello_Ticket Normale ↔ schermata "singolo ticket" (mancante nel codice)
### 13 — Carrello_TicketVip ↔ schermata "singolo ticket" (mancante nel codice)

**Specifiche Figma (px-perfect):**
- **Sfondo schermata**: `linear-gradient(180deg, #000000 0%, #060037 100%)`.
- **Card centrale enorme**: `width 370 height 527, left 12 top 162`, sfondo `linear-gradient(180deg, #000000 0%, #0015FF 100%)`, border-radius `10`.
- Dentro la card:
  - `"Ticket"`: Helvetica `50/57 w400 letter-spacing -0.1em`, `left 21 top 23`.
  - `"Normale"` (12) / `"Vip"` (13): **Helvetica Light** `48/59 w400 letter-spacing -0.06em`, `left 77/82 top 59/66`.
  - Prezzo `"10€"` / `"25€"`: Helvetica **`192/221 w400 letter-spacing -0.08em`** (font GIGANTE 192px), occupa la metà centrale della card.
  - `"+ 2 drink omaggio"` (Normale): Helvetica `24/28 w400 letter-spacing -0.1em`, `text-align right`, `left 177 top 319`.
  - `"+ 2 drink omaggio + Salta fila + Ticket guarda roba amaggio"` (Vip): stesso stile multi-line.
  - `"Entrata valida per questo ticket entro le 00:00 am"`: Helvetica `24/28 w400 letter-spacing -0.1em`, `text-align center`, `left 54 top 454`.
- **Top bar**: logo + search + profile (immutati), poi `← Torna indietro` Helvetica Neue `32 w300`.
- **Bottone full-width "AGGIUNGI AL CARRELLO"**: 
  - `370×43, left:11 top:710` (la 12) / `top:711` (la 13)
  - Sfondo `linear-gradient(90deg, #1800D2 19.48%, #120099 100%)`, border-radius `10`.
  - Testo `"AGGIUNGI AL CARRELLO"`: Helvetica `24/28 w700 letter-spacing -0.07em`, larghezza 268px, centrato.

**Cosa manca nel codice:**
- Queste schermate **non esistono**. In `booking_screen.dart` lo step `ticketList` (la 11) ha bottone "PRENOTA" che porta dritto alla `cart_screen` (la 14), saltando il dettaglio del singolo ticket. Da decidere se aggiungere il passo intermedio.
- **Wording**: la 11 ha "PRENOTA" (= scegli questo ticket) e la 12/13 ha "AGGIUNGI AL CARRELLO" (= conferma e vai al carrello). Sono **due azioni distinte**, non sinonime.

---

### 14 — Carrello con qualcosa ↔ `cart_screen.dart` (stato pieno, ticket)

**Specifiche Figma (px-perfect):**
- **Sfondo schermata**: `linear-gradient(180deg, #000 0%, #060037 100%)`.
- **Card riepilogo (piccola, NON full-screen)**:
  - `width 353 height 175, left 18 top 170`
  - Sfondo `linear-gradient(180deg, #1E00FF 0%, #020011 100%)`, border-radius `10`.
- Dentro la card:
  - `"Ticket x 1"`: Helvetica `39.52/45 w400 letter-spacing -0.1em`, `left 29 top 181`.
  - `"Ticket normale"` (sottotitolo a destra): Helvetica Light `20/25 w400 letter-spacing -0.06em`, `left 207 top 197`.
  - `"10€"`: Helvetica `96/110 w400 letter-spacing -0.1em`, `left 29 top 222`.
  - `"+ 2 drink omaggio"`: Helvetica `24/28 w400 letter-spacing -0.1em`, `left 195 top 263`.
- **Bottone full-width "ORDINA IL TUO POSTO ORA"** in fondo (sopra la nav bar):
  - `370×43, top 84.39%` (≈ top 719), `width 293` centrato.
  - Sfondo `linear-gradient(90deg, #1800D2 19.48%, #120099 100%)`, border-radius `10`.
  - Testo `Helvetica 24/28 w700 letter-spacing -0.07em`.
- **Tab carrello attiva**: highlight `73×43 rgba(255,255,255,0.24) border-radius 7` sotto l'icona, posizione `left:206 top:778`.

**Differenze dal codice:**
- Codice ha `Colors.black` (no gradiente), card `Color(0xFF1900D8)` solido (no gradiente).
- Card del codice è **a tutto schermo** (`Expanded` + `Container` con `SingleChildScrollView`) — Figma è **piccola in alto** (175px).
- **Codice contiene TextField per Nome+Data nascita di ogni intestatario** + selettore `Quantità +/-` ([cart_screen.dart:294-398](lib/presentation/cart_screen/cart_screen.dart#L294-L398)) — questi NON sono nel Figma 14.
- Codice ha due bottoni `"ALTRO"` + `"PAGA"` split 50/50 — Figma ha unico `"ORDINA IL TUO POSTO ORA"` full-width.
- Manca completamente la struttura "Ticket x 1" + descrizione minimale del Figma.

Questa è probabilmente **la schermata più disallineata di tutte**.

---

### 15 — Ordine Effettuato ↔ `payment_success_screen.dart`

**Specifiche Figma (px-perfect):**
- **Sfondo schermata**: `linear-gradient(180deg, #000 0%, #060037 100%)`.
- **Tipografia particolare** (è un layout "a cascata" sfasato a destra, non centrato):
  - `"ORDINE"`: Helvetica Neue `64/63 w300 letter-spacing -0.07em`, posizione `left:40 top:331`, larghezza 209px.
  - `"EFFETTUATO"`: Helvetica Neue `36/36 w300 letter-spacing -0.07em`, posizione `left:163 top:382` (più a destra di ORDINE, quasi sotto la "E" finale).
  - `"Buon divertimento!"`: Helvetica Neue `20/20 w300 letter-spacing -0.07em`, posizione `left:213 top:416` (ancora più a destra).
  - Tutto in `w300` (light), non bold come avevo scritto.
- **Bottone "TORNA NELLA HOME"**: 370×43 a `top:711`, sfondo `linear-gradient(90deg, #1800D2 19.48%, #120099 100%)`, border-radius `10`. Testo Helvetica `24/28 w700 letter-spacing -0.07em`, larghezza testo 224px, centrato (`calc(50% - 224px/2 + 9.5px)`).
- **Tab carrello attiva** (3°): highlight `73×43 rgba(255,255,255,0.3) left:206 top:778`.

**Differenze dal codice:**
- Codice ha titolo `"Ordine effettuato"` minuscolo, una sola riga, `32px Inter bold` — Figma ha 3 livelli in cascata `w300` (light), tutti maiuscoli per il titolo principale.
- Codice manca `"Buon divertimento!"` completamente.
- Bottone codice è `"Vedi i tuoi ordini"` `Color(0xFF1D00FF)` solido → ordersScreen — Figma è `"TORNA NELLA HOME"` con gradiente → home. Wording, colore, azione **tutti** diversi.
- Codice ha back custom `Icons.arrow_back + "Torna indietro"` ([payment_success_screen.dart:63-84](lib/presentation/payment_success_screen/payment_success_screen.dart#L63-L84)) — Figma non ha "Torna indietro" in questa schermata (è una landing terminale del flusso).

---

### 16 — Notifiche ↔ `notifications_screen.dart`

**Specifiche Figma (px-perfect):**
- **Sfondo schermata**: `linear-gradient(180deg, #000 0%, #060037 100%)`.
- **Tipografia label "Data"** (titolo sopra ogni card): Helvetica `28/32 w400 letter-spacing -0.1em`, `left:17 top:108` (prima) e `left:17 top:215` (seconda).
- **Card notifica** (es. "Frame 351" / "Frame 353"):
  - `width 369 height 66, left 12, top 142` (prima) / `top 249` (seconda)
  - Sfondo `linear-gradient(90deg, rgba(255,255,255,0.2) 0%, rgba(30,0,255,0.2) 100%)` (prima) / `rgba(25,0,216,0.2) 100%` (seconda — differenza minima, forse refuso Figma)
  - border-radius `10`
  - Testo `"Prevendita"`: Helvetica `39.52/45 w400 letter-spacing -0.1em`, larghezza 154px.
- **Tab campanella attiva** (4°): highlight `73×43 rgba(255,255,255,0.25) left:295 top:782`.

**Differenze dal codice:**
- Codice ha `Colors.black` puro (no gradiente).
- Codice ha **titolo "Notifiche" 32px bold** in alto ([notifications_screen.dart:75-91](lib/presentation/notifications_screen/notifications_screen.dart#L75-L91)) — Figma **non ha alcun titolo di pagina**.
- Codice ha card `Color(0xFF1A1A1A)` / `#252525` con icona+titolo+messaggio+badge — Figma ha solo `"Data"` (label) + card grande `"Prevendita"`. **Modelli notifica totalmente diversi**.
- Codice supporta tipologie (`prenotazione` / `consiglio` / `sistema`) — Figma mostra solo prevendite.
- Da chiarire se il Figma 16 è uno stub minimale o il design definitivo.

---

### 17 — Riepilogo ticket acquistati ↔ `orders_screen.dart`

**Specifiche Figma (px-perfect):**
- **Sfondo schermata**: `linear-gradient(180deg, #000 0%, #060037 100%)`.
- **Titolo "Oggi"**: Helvetica `36/41 w700 letter-spacing -0.07em`, `left:18 top:171` (è uno **header di sezione**, non un titolo di pagina).
- **Card prevendita acquistata** (Rectangle 169):
  - `width 353 height 222, left 16 top 227`
  - Sfondo `linear-gradient(180deg, #1E00FF 0%, #020011 100%)`, border-radius `10`.
- Dentro la card:
  - `"Ticket x 1"`: Helvetica `39.52/45 w400 letter-spacing -0.1em`, `left:27 top:236`.
  - `"Ticket normale"`: Helvetica Light `20/25 w400 letter-spacing -0.06em`, `left:175 top:254`.
  - `"10€"`: Helvetica `96/110 w400 letter-spacing -0.1em`, `left:27 top:279`.
  - `"+ 2 drink omaggio"`: Helvetica `24/28 w400 letter-spacing -0.1em`, `left:193 top:320`.
- **Link "Visualizza QR Code"** in basso alla card:
  - Testo: Helvetica Neue `15/15 w400 letter-spacing -0.1em`, `left:139 top:393`.
  - Cerchio outline `28×28 border 2px white` a fianco (`left:174 top:412`), con dentro `arrow_back 43.62×43.62 ruotata -90°` (freccia in basso).
- **Tab Borsa attiva** (2°): highlight `73×43 rgba(255,255,255,0.19) left:115 top:778`.

**Differenze dal codice:**
- Codice usa `TabBar` con 2 tab `"Prevendite" / "Tavoli"` + lista card `_buildPrevenditaCard` (`#1A1A1A` con icone, stato, prezzo, nominativo) — Figma ha **header data + card grande con QR inline-link**.
- Codice non raggruppa per data (Oggi/Domani/...) — Figma sì.
- Codice non ha il link "Visualizza QR Code" con cerchio+freccia — l'azione di vedere il QR è una navigazione separata.
- Tab Borsa non esiste in `SharedFooter` (vedi finding §0.3): codice usa `currentIndex: -1`.

---

### 18 — Riepilogo ticket acquistati - QR ↔ `prevendita_detail_screen.dart`

**Specifiche Figma (px-perfect):**
- **Sfondo schermata**: `linear-gradient(180deg, #000 0%, #060037 100%)`.
- **Card grande con QR** (Rectangle 169 espanso):
  - `width 353 height 601, left 20 top 162`
  - Sfondo `linear-gradient(180deg, #1E00FF 0%, #020011 100%)`, border-radius `10`.
- Dentro la card (parte alta, identica alla 17):
  - `"Ticket x 1"`: Helvetica `39.52/45 w400 letter-spacing -0.1em`, `left:31 top:171`.
  - `"Ticket normale"`: Helvetica Light `20/25 w400`, `left:179 top:189`.
  - `"10€"`: Helvetica `96/110 w400 letter-spacing -0.1em`, `left:31 top:214`.
  - `"+ 2 drink omaggio"`: Helvetica `24/28 w400`, `left:197 top:255`.
- **QR code**:
  - `width 258 height 258, left:63 top:330`.
- **Pill "ANNULLA PREVENDITA"** (sotto al QR, dentro la card):
  - Sfondo pill: `Rectangle 201: 219×35 rgba(255,255,255,0.13) border-radius:10`, `left:86 top:609`.
  - Testo: Helvetica `20/23 w700 letter-spacing -0.07em`, `width 206 left:94 top:615`, colore bianco.
- **Link "Chiudi QR Code"** sotto la card (fuori della card):
  - Testo: Helvetica Neue `15/15 w400 letter-spacing -0.1em`, `left:151 top:702`.
  - Cerchio outline `28×28 border 2px white` (`left:182 top:721`), con dentro freccia ruotata +90° (verso il basso, opposta alla 17).
- **Tab Borsa attiva** (2°): highlight `73×43 rgba(255,255,255,0.19) left:115 top:778`.

**Differenze dal codice:**
- Codice ha sfondo `Colors.black`, card con QR di dimensioni e gradienti diversi (`#000 → #1900D8 stops 0/0.8173` vs `#1E00FF → #020011`).
- Codice mette `"Data + Nome Club + Nome cognome + Tipo di Prevendita"` **fuori dalla card** ([prevendita_detail_screen.dart:113-200](lib/presentation/prevendita_detail_screen/prevendita_detail_screen.dart#L113-L200)) — Figma mette TUTTO **dentro** la card grande (Ticket x 1, prezzo, + 2 drink omaggio, QR, ANNULLA).
- **Manca bottone "ANNULLA PREVENDITA"** (CLAUDE.md §1.6 lo definisce flusso critico).
- **Manca link "Chiudi QR Code"** con cerchio+freccia — codice chiude solo con back nativo.
- Codice ha link al `clubDetailScreen` cliccando sul nome club — Figma non ha questa interazione.

---

## 3. Punti incerti / da chiarire prima di procedere

Domande che hanno impatto sulle correzioni:

1. **Image 09**: davvero manca o l'ho persa?
2. **Bottom nav**: devo riallineare al Figma (Home / Borsa / Carrello / Campanella) rimuovendo la tab Profilo? Profilo resta solo come icona in alto a destra?
3. **Sign up — campo Telefono**: lo tengo (è funzionale) o lo nascondo come da Figma?
4. **Location permission**: la pre-permission screen custom va sostituita dal solo prompt nativo, o rimane?
5. **Location manual — campo CAP**: lo riattivo come da Figma, o resta nascosto?
6. **Club detail — sezioni "Come arrivare / Recensioni / Trasporti"**: tengo o rimuovo (Figma non le ha)?
7. **Booking ticket — flusso 11 → 12/13 → 14**: aggiungo la schermata intermedia singolo ticket con "AGGIUNGI AL CARRELLO" o lascio il flusso diretto attuale?
8. **Cart screen — TextField intestatari**: presenti nel codice ma non nel Figma. Tengo (necessari per la prenotazione) o nascondo?
9. **Payment success**: bottone "TORNA NELLA HOME" (Figma) o "Vedi i tuoi ordini" (codice attuale)?
10. **Notifiche**: layout codice (ricco, con tipologie) o layout Figma (minimal, solo prevendite per data)?
11. **Orders screen**: layout codice (TabBar Prevendite/Tavoli) o layout Figma (sezioni per data + card espandibile con QR)?
12. **Annulla prevendita**: il bottone "ANNULLA PREVENDITA" nel dettaglio prevendita è un flusso critico secondo CLAUDE.md §1.6 ma non è implementato nella schermata. Lo aggiungo?
13. **Font Helvetica**: il design impone Helvetica/Helvetica Neue. Su mobile Flutter va aggiunto agli assets (CLAUDE.md dice di verificare con il team prima dei font pesanti). Procedo a integrarlo, o uso il fallback di sistema (SF Pro su iOS, Roboto su Android)?

---

## 4. Stato

Tutto auditato. Nessuna modifica al codice eseguita. Aspetto tuo OK su:
- abbinamenti (§1)
- elenco differenze per schermata (§2)
- risposte alle domande (§3)

prima di procedere con la FASE 1 (correzioni schermata per schermata, una alla volta, con `flutter analyze` + `flutter test` dopo ognuna come da CLAUDE.md §4).
