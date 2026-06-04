# `lib/presentation/`

UI dell'app, organizzata **feature-first**: una sottocartella per ogni schermata.
Ogni cartella `<screen_name>/` contiene tutto quello che serve a quella schermata —
widget, BLoC, model di state — così la feature è autocontenuta.

## Convenzioni

Quando una schermata ha logica non banale, la struttura è:

```
<screen_name>/
├── <screen_name>.dart          ← Widget (UI). Espone static Widget builder(context)
├── README.md                   ← (opzionale) flusso utente, regole di business, edge case
├── bloc/
│   ├── <screen_name>_bloc.dart   ← extends Bloc<Event, State>
│   ├── <screen_name>_event.dart  ← sealed events (part of bloc)
│   └── <screen_name>_state.dart  ← state con Equatable (part of bloc)
└── models/
    └── <screen_name>_model.dart  ← view-model UI (form state, draft, ecc.)
```

Schermate semplici (es. `payment_success_screen`, `notifications_screen`,
`splash_screen`) NON hanno `bloc/` né `models/`: gestiscono il poco stato
necessario con `setState` o leggono direttamente dai servizi.

> I **domain model** condivisi (Locale, Serata, Città, Notification) vivono in
> [`lib/core/models/`](../core/models/), non qui. In `presentation/<screen>/models/`
> stanno solo i view-model temporanei della singola schermata.

## Indice schermate

I dettagli del flusso utente di ogni schermata sono nei rispettivi README. Quelle
elencate qui sotto senza link non hanno (ancora) un README dedicato.

### Onboarding & autenticazione
- [`authentication_screen/`](authentication_screen/README.md) — login email/password, Google, Apple
- [`sign_up_screen/`](sign_up_screen/README.md) — registrazione (form dati + telefono)
- [`verification_screen/`](verification_screen/README.md) — attesa conferma email + timer OTP
- `verification_failure_screen/` — fallback se la verifica non va a buon fine
- [`complete_profile_screen/`](complete_profile_screen/README.md) — dati mancanti post-OAuth

### Posizione
- [`location_permission_screen/`](location_permission_screen/README.md) — richiesta permesso GPS
- [`location_manual_screen/`](location_manual_screen/README.md) — selezione città manuale

### Home & scoperta
- `splash_screen/` — entry point, decide la rotta in base allo stato auth
- [`home_screen/`](home_screen/README.md) — feed locali vicini + serate in evidenza
- [`nearby_clubs_screen/`](nearby_clubs_screen/README.md) — lista locali filtrati per raggio + mappa
- [`club_detail_screen/`](club_detail_screen/README.md) — scheda club
- `event_info_popup_screen/` — pop-up info serata (Figma 19), aperto dal tap su una serata nel club
- `main_layout_screen/` — layout con bottom nav usato come shell delle tab

### Acquisto & ordini
- [`booking_screen/`](booking_screen/README.md) — prevendite/tavoli + carrello
- [`cart_screen/`](cart_screen/README.md) — riepilogo carrello e checkout
- [`payment_success_screen/`](payment_success_screen/README.md) — conferma post-checkout
- [`orders_screen/`](orders_screen/README.md) — storico ordini dell'utente
- [`prevendita_detail_screen/`](prevendita_detail_screen/README.md) — dettaglio singola prevendita (con QR + annullamento)
- [`tavolo_detail_screen/`](tavolo_detail_screen/README.md) — dettaglio singolo tavolo prenotato

### Profilo & sistema
- `profile_screen/` — dati utente, raggio km, logout
- `notifications_screen/` — lista notifiche

### Schermate da verificare (vedi nota in fondo)
- [`event_detail_screen/`](event_detail_screen/README.md) — possibile codice morto
- `table_map_screen/` — possibile codice morto

> **Nota:** `event_detail_screen` e `table_map_screen` sono attualmente non
> raggiungibili dalle routes (la prima ha l'alias che porta a `home_screen`,
> la seconda non è registrata). Sono candidate alla rimozione — vedi
> commit di refactor sul branch.
