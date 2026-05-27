# OnListClub — Documentazione per sviluppatori

---

## Cos'è OnList

**OnList** è una piattaforma mobile per scoprire, seguire e prenotare eventi nelle discoteche e nei club.

L'idea di fondo è semplice: l'utente apre l'app, vede i club vicini a lui, guarda le serate in programma questa notte (o nei prossimi giorni), e prenota il suo posto con pochi tap — senza code, senza intermediari.

Dal lato dei club, OnList è uno strumento per gestire le proprie serate, le liste, i posti disponibili e la comunicazione con i clienti.

**In sintesi:**
- Per l'utente: trovare il locale giusto nella propria città, vedere cosa c'è stasera, prenotare
- Per il club: gestire con un gestionale serate ed eventi, comunicare con i clienti, avere una lista digitale

L'app è mobile-first (iOS e Android), costruita con Flutter e Supabase come backend.

---

## Ruoli nel team di sviluppo

> Aggiorna questa tabella con i nomi del team.

| Ruolo | Responsabilità | Nome |
|---|---|---|
| **Tech Lead / Dev Flutter** | Architettura app, BLoC, schermate principali | _(da aggiungere)_ |
| **Backend Developer** | Database Supabase, RPC, policy RLS, query SQL | _(da aggiungere)_ |
| **UI/UX Designer** | Figma, design system, flussi utente | _(da aggiungere)_ |
| **Product Owner** | Requisiti, priorità, roadmap features | _(da aggiungere)_ |

---

## Ruoli nell'app

L'app distingue tre tipi di utente, con permessi diversi:

### Utente normale (user)
- Si registra con email/password, Google o Apple
- Visualizza i club vicini e le serate in programma
- Prenota il proprio posto a una serata
- Salva i club preferiti
- Gestisce il proprio profilo

### Gestore locale (manager) — in sviluppo
- Accede a una dashboard dedicata al proprio club
- Crea e modifica le serate del locale
- Visualizza le prenotazioni e gestisce la lista
- Può aggiungere foto, generi musicali, orari e prezzi

### Amministratore (admin) — interno
- Accesso completo al database via Supabase Dashboard
- Gestisce i locali, approva nuovi club, monitora i dati
- Configura le RLS policy e le funzioni RPC

---

## Indice generale

### Setup e installazione
- [INSTALL.md](INSTALL.md) — Installazione Flutter, Android SDK, iOS, avvio dell'app

### Architettura e configurazione
- [Configurazione app](lib/main.dart) — Inizializzazione Supabase, orientamento, routing
- [Rotte](lib/routes/app_routes.dart) — Tutte le rotte e la schermata iniziale
- [Dipendenze](pubspec.yaml) — Tutti i pacchetti usati nel progetto

### Schermate (Presentation Layer)

Ogni schermata ha il suo README con la spiegazione del codice e della logica.

| Schermata | Descrizione | README |
|---|---|---|
| **Login** | Accesso con email/password, Google, Apple | [authentication_screen](lib/presentation/authentication_screen/README.md) |
| **Registrazione** | Creazione account con dati personali | [sign_up_screen](lib/presentation/sign_up_screen/README.md) |
| **Verifica email** | Attesa e controllo conferma email | [verification_screen](lib/presentation/verification_screen/README.md) |
| **Completa profilo** | Dati aggiuntivi post-login OAuth | [complete_profile_screen](lib/presentation/complete_profile_screen/README.md) |
| **Permesso posizione** | Richiesta accesso GPS | [location_permission_screen](lib/presentation/location_permission_screen/README.md) |
| **Posizione manuale** | Selezione città manuale | [location_manual_screen](lib/presentation/location_manual_screen/README.md) |
| **Home / Evento** | Schermata principale con club e evento | [event_detail_screen](lib/presentation/event_detail_screen/README.md) |
| **Dettaglio club** | Informazioni complete su un club | [club_detail_screen](lib/presentation/club_detail_screen/README.md) |
| **Prenotazione** | Schermata prenotazione (in sviluppo) | [booking_screen](lib/presentation/booking_screen/README.md) |

### Servizi e logica core

| File | Scopo |
|---|---|
| [register_service.dart](lib/core/services/register_service.dart) | Registrazione utente su Supabase |
| [phone_service.dart](lib/core/services/phone_service.dart) | Gestione e normalizzazione numeri di telefono |
| [club_service.dart](lib/core/services/club_service.dart) | Fetch dei club dal database |
| [location_service.dart](lib/core/services/location_service.dart) | Rilevamento posizione GPS |
| [user_profile_manager.dart](lib/core/services/user_profile_manager.dart) | Creazione e lettura del profilo utente in `public.utenti` |
| [age_calculator.dart](lib/core/utils/age_calculator.dart) | Calcolo maggiore età |
| [navigator_service.dart](lib/core/services/navigator_service.dart) | Navigazione centralizzata tra schermate |
| [image_constant.dart](lib/core/constants/image_constant.dart) | Path statici degli asset immagine |

---

## Flusso principale dell'app

```
App avviata
    |
    v
[Login Screen]
    |-- credenziali ok --> verifica posizione GPS
    |                           |-- prima volta --> [Location Permission]
    |                           |-- già impostata --> [Home / Evento]
    |-- nuovo utente --> [Sign Up] --> [Verifica Email] --> [Home / Evento]
    |-- OAuth (Google/Apple) --> [Completa Profilo se mancano dati] --> [Home]
```

---

## Struttura del database (Supabase)

- `users` — dati anagrafici (nome, cognome, data_nascita, maggiorenne)
- `users_phones` — numeri di telefono dell'utente con prefisso paese
- `countries` — paesi con codice ISO e prefisso telefonico
- `locali` — club/locali con nome, indirizzo, foto, generi musicali
- `serate` — eventi/serate collegate ai locali

La persistenza avviene tramite una funzione RPC transazionale:
`register_user_transaction` — inserisce atomicamente utente + telefono dopo la verifica email.

---

## Stack tecnico

- **Frontend mobile:** Flutter (Dart SDK `^3.6.0`), target iOS + Android
- **State management:** [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) `^9.1.1` + `equatable`
- **Backend / DB / Auth:** [Supabase](https://supabase.com) (Postgres + RLS + RPC)
- **Auth social:** Google Sign-In, Sign in with Apple
- **Mappa:** `flutter_map` + `latlong2`, geocoding via `geolocator` + `geocoding`
- **Networking immagini:** `cached_network_image`
- **Font/styling:** `google_fonts` + design system definito in [.claude/CLAUDE.md](.claude/CLAUDE.md)

L'elenco completo delle dipendenze è in [pubspec.yaml](pubspec.yaml).

---

## Setup e avvio

```bash
# 1. Installa le dipendenze
flutter pub get

# 2. Verifica che tutto compili e i lint passino
flutter analyze
flutter test

# 3. Avvia su un device/emulatore connesso
#    Le chiavi Supabase vanno passate via --dart-define (mai committate).
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<client-id>
```

In assenza di `--dart-define` l'app fa fallback su `env.json` (solo per dev locale,
**non** versionato). Vedi [INSTALL.md](INSTALL.md) per il setup di Flutter, Android
SDK e Xcode.

---

## Struttura del progetto

```
OnListClub_app/
├── README.md                ← questo file
├── pubspec.yaml             ← dipendenze e asset
├── android/, ios/, web/     ← cartelle di piattaforma generate da Flutter
├── assets/                  ← immagini, logo, env.json (dev only)
├── docs/                    ← documentazione tecnica e schema DB
├── test/                    ← test automatici
└── lib/                     ← tutto il codice Dart dell'app
    ├── main.dart            ← entry point: init Supabase + MaterialApp
    ├── core/                ← layer non-UI (vedi lib/core/README.md)
    │   ├── app_export.dart  ← barrel: riesporta tipi e helper più usati
    │   ├── constants/       ← path asset, costanti statiche
    │   ├── models/          ← domain models (Locale, Serata, Città, Notification)
    │   ├── services/        ← Supabase, GPS, navigator, profilo utente
    │   └── utils/           ← helper puri (date, età, telefono, size)
    ├── routes/              ← mappa rotte e nomi (AppRoutes)
    ├── theme/               ← colori e text style del design system
    ├── widgets/             ← componenti UI riutilizzabili globali
    └── presentation/        ← una cartella per schermata (UI + BLoC + model)
```

Ogni cartella principale di `lib/` ha un proprio `README.md` con il dettaglio
dei file e del loro ruolo. La maggior parte delle schermate in
`lib/presentation/` ha già un README dedicato al flusso utente.

> Le regole di progetto (design system, convenzioni di codice, qualità) sono
> dichiarate in [.claude/CLAUDE.md](.claude/CLAUDE.md) — leggere prima di
> contribuire.

---

## Licenza

Progetto interno OnListClub. Vedere [LICENSE](LICENSE) per i dettagli.
