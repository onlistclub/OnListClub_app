# `lib/core/`

Layer non-UI dell'app. Contiene tutto ciò che NON dipende da `flutter/material.dart`
per la sua logica (modelli, accesso al DB Supabase, helper puri) oltre ai servizi
runtime che hanno bisogno di Flutter ma non hanno una UI propria
(es. `NavigatorService`).

## Struttura

| Sottocartella | Cosa contiene |
|---|---|
| [`constants/`](constants/) | Costanti statiche dell'app (path degli asset, chiavi). |
| [`models/`](models/) | Domain model condivisi: rappresentazioni delle tabelle Supabase usate ovunque (`LocaleModel`, `SerataModel`, ecc.). |
| [`services/`](services/) | Logica di accesso a Supabase, GPS, profilo utente, navigazione, analytics. Un servizio per dominio. |
| [`utils/`](utils/) | Helper **puri**: calcolo età, formattazione date, normalizzazione telefoni, calcolo dimensioni responsive. Nessuno stato. |

## File a questo livello

- **`app_export.dart`** — file _barrel_ che ri-esporta i tipi più usati
  (`NavigatorService`, `AppRoutes`, `ImageConstant`, theme helper, `CustomImageView`,
  `flutter_bloc`, `equatable`). Molti file di `presentation/` lo importano una sola
  volta invece di elencare tutte le sue export.

## Regole

- I file in `models/` non importano `flutter/material.dart`.
- I file in `services/` non importano widget né schermate (`presentation/`).
- I file in `utils/` non hanno stato, non chiamano Supabase, non fanno I/O.
- Tutto ciò che parla con Supabase vive in `services/`, mai sparso nei widget.
