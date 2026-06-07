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
- [ARCHITETTURA.md](docs/ARCHITETTURA.md) — Come è strutturato il flusso dell'app, auth, sessione e collegamento con Supabase

### Database (Supabase)
- [DATABASE.md](DATABASE.md) — Panoramica delle tabelle principali e della sicurezza, in linguaggio semplice
- [docs/database/struttura_database.md](docs/database/struttura_database.md) — Riferimento tecnico completo: schema, RLS, trigger, view, flussi end-to-end

### Regole di progetto
- [.claude/CLAUDE.md](.claude/CLAUDE.md) — Design system, convenzioni di codice, regole di qualità. **Da leggere prima di contribuire.**

### Schermate (Presentation Layer)

Ogni schermata vive in `lib/presentation/<nome>/`. Per le schermate dei flussi critici (login, registrazione, prenotazione, ordini) esiste un README dedicato con il dettaglio della logica.

| Schermata | Descrizione | README dedicato |
|---|---|---|
| **Splash** | Bootstrap: legge la sessione persistente Supabase e decide se andare a login o home | — |
| **Login** | Accesso con email/password, Google, Apple | [authentication_screen](lib/presentation/authentication_screen/README.md) |
| **Registrazione** | Creazione account con dati personali | [sign_up_screen](lib/presentation/sign_up_screen/README.md) |
| **Verifica email** | Attesa e controllo conferma email (con timer + resend) | [verification_screen](lib/presentation/verification_screen/README.md) |
| **Errore verifica** | Schermata di errore se il link di verifica fallisce | — |
| **Completa profilo** | Dati aggiuntivi post-login OAuth (Google/Apple) | [complete_profile_screen](lib/presentation/complete_profile_screen/README.md) |
| **Permesso posizione** | Richiesta accesso GPS al primo avvio | [location_permission_screen](lib/presentation/location_permission_screen/README.md) |
| **Posizione manuale** | Selezione città manuale se l'utente nega il GPS | [location_manual_screen](lib/presentation/location_manual_screen/README.md) |
| **Home** | Schermata principale: club vicini e serate consigliate | — |
| **Dettaglio club** | Informazioni complete su un club (foto, generi, contatti, serate) | [club_detail_screen](lib/presentation/club_detail_screen/README.md) |
| **Dettaglio evento** | Pagina di una singola serata di un club | [event_detail_screen](lib/presentation/event_detail_screen/) |
| **Pop-up info evento** | Pop-up rapido informativo su una serata | — |
| **Locali vicini** | Lista club ordinati per distanza dall'utente | — |
| **Dettaglio prevendita** | Selezione tipologia biglietto (Normale, VIP, Uomo, …) | — |
| **Dettaglio tavolo** | Selezione tavolo e configurazione drink | — |
| **Prenotazione** | Schermata generica di prenotazione | [booking_screen](lib/presentation/booking_screen/README.md) |
| **Carrello** | Riepilogo articoli selezionati prima del checkout | — |
| **Conferma pagamento** | Schermata di successo con QR code di ingresso | — |
| **Ordini** | Storico ordini e prenotazioni dell'utente | — |
| **Profilo** | Dati personali, preferiti, logout | — |
| **Notifiche** | Lista notifiche utente con stato letto/non letto | — |

I README delle schermate marcate "—" verranno aggiunti per i flussi critici (CLAUDE.md §1) man mano che si lavora sulle relative funzionalità.

### Servizi e logica core

| File | Scopo |
|---|---|
| [auth_service.dart](lib/core/services/auth_service.dart) | Wrapper attorno a Supabase Auth: login, logout, listener globale sulla sessione |
| [register_service.dart](lib/core/services/register_service.dart) | Registrazione utente (chiamata alla RPC `register_user_transaction`) |
| [user_profile_manager.dart](lib/core/services/user_profile_manager.dart) | Creazione e lettura del profilo utente in `public.utenti` |
| [club_service.dart](lib/core/services/club_service.dart) | Fetch dei locali dal database (con embed di eventi e prenotazioni) |
| [booking_service.dart](lib/core/services/booking_service.dart) | Prenotazione tavoli: pre-check disponibilità + insert con gestione overbooking |
| [orders_service.dart](lib/core/services/orders_service.dart) | Lettura unificata di ordini, prevendite e prenotazioni tavolo dell'utente |
| [notification_service.dart](lib/core/services/notification_service.dart) | Lettura/aggiornamento notifiche utente |
| [badge_service.dart](lib/core/services/badge_service.dart) | Conteggio notifiche non lette (badge sull'icona) |
| [analytics_service.dart](lib/core/services/analytics_service.dart) | Logging eventi su `analytics_events` |
| [location_service.dart](lib/core/services/location_service.dart) | Rilevamento posizione GPS + persistenza flag manuale/forzata |
| [navigator_service.dart](lib/core/services/navigator_service.dart) | Navigazione centralizzata tra schermate (chiave globale per Navigator) |
| [age_calculator.dart](lib/core/utils/age_calculator.dart) | Calcolo maggiore età |
| [image_constant.dart](lib/core/constants/image_constant.dart) | Path statici degli asset immagine |

Per il dettaglio dei pattern e dei file interni di ogni cartella, vedi i README in [lib/core/](lib/core/README.md), [lib/core/services/](lib/core/services/README.md), [lib/core/utils/](lib/core/utils/README.md), [lib/core/models/](lib/core/models/README.md).

---

## Flusso principale dell'app

```
[Splash]
   |
   |-- sessione Supabase valida + profilo completo --> [Home]
   |-- sessione Supabase valida ma profilo incompleto (OAuth) --> [Completa profilo] --> [Home]
   |-- nessuna sessione --> [Login]
                              |
                              |-- credenziali ok --> [Home]
                              |-- "registrati" --> [Sign Up] --> [Verifica email] --> [Home]
                              |-- Google / Apple --> [Completa profilo se mancano dati] --> [Home]

[Home]
   |-- club vicini? --> sì → mostra lista
   |                   no  → [Permesso posizione] → [Permesso GPS o città manuale]
   |
   |-- tocca un club --> [Dettaglio club]
                             |-- tocca una serata --> [Dettaglio evento]
                                                          |-- "Prevendite" --> [Dettaglio prevendita] --> [Carrello] --> [Conferma pagamento + QR]
                                                          |-- "Tavoli"     --> [Dettaglio tavolo]     --> [Carrello] --> [Conferma pagamento + QR]
```

Per il dettaglio dei vari flussi (bootstrap della sessione, gestione auth, comunicazione con Supabase) vedi [docs/ARCHITETTURA.md](docs/ARCHITETTURA.md).

---

## Struttura del database (Supabase)

Le tabelle principali (schema `public`):

| Tabella | Cosa contiene |
|---|---|
| `utenti` | Dati anagrafici (nome, cognome, data_nascita, maggiorenne) |
| `utenti_numeri_telefono` | Numeri di telefono dell'utente con prefisso paese |
| `paesi`, `citta`, `cap`, `provincia` | Geografia di riferimento per indirizzi e prefissi |
| `locali` | Club / discoteche (nome, indirizzo, foto, generi musicali, capienza) |
| `eventi` | Serate collegate a un locale |
| `prevendite` | Tipologie di biglietti vendibili per un evento (Normale, VIP, ecc.) |
| `prenotazioni_prevendite` | Biglietti acquistati dagli utenti |
| `tavoli`, `tavoli_eventi`, `prenotazioni_tavolo` | Tavoli, disponibilità per serata, prenotazioni |
| `drink` | Catalogo bottiglie / drink |
| `ordini` | Ordini drink (placeholder per integrazione Stripe futura) |
| `preferiti` | Locali preferiti dell'utente |
| `notifiche` | Notifiche utente |
| `analytics_events` | Eventi di analytics |
| `gestori`, `staff`, `ingressi_giornalieri` | Tabelle del gestionale (in sviluppo) |

La persistenza dell'utente al termine della registrazione avviene tramite la RPC transazionale `register_user_transaction`, che inserisce atomicamente utente + telefono dopo la verifica email.

La separazione dei dati tra app utente e gestionale è garantita dalla **Row Level Security** (RLS) di Postgres, con la function `my_club_id()` che identifica il club del gestore loggato. Per i dettagli (schema, policy RLS, trigger, view, flussi end-to-end):
- 👉 [DATABASE.md](DATABASE.md) — riepilogo veloce
- 👉 [docs/database/struttura_database.md](docs/database/struttura_database.md) — riferimento tecnico completo

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
