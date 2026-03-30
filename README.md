# OnListClub — Documentazione per sviluppatori

**OnListClub** è un'app mobile Flutter per la gestione di eventi e liste nei club.
Backend: Supabase. Gestione dello stato: BLoC.

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
| [user_profile_manager.dart](lib/core/utils/user_profile_manager.dart) | Creazione profilo post-verifica email |
| [age_calculator.dart](lib/core/utils/age_calculator.dart) | Calcolo maggiore età |
| [navigator_service.dart](lib/core/utils/navigator_service.dart) | Navigazione centralizzata tra schermate |

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

## Licenza

Progetto interno OnListClub. Vedere [LICENSE](LICENSE) per i dettagli.
