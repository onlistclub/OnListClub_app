# `lib/core/services/`

Servizi applicativi: ogni file incapsula la logica di **un dominio** (autenticazione,
locali, prenotazioni, ecc.) e nasconde il client Supabase al resto dell'app. I widget
NON parlano mai direttamente con Supabase: passano sempre da un servizio.

Convenzioni:
- Metodi `static` quando il servizio è stateless (es. `ClubService`, `BookingService`).
- Singleton (`factory`) quando il servizio mantiene stato runtime (es. `BadgeService`,
  `UserProfileManager`, `NavigatorService`).
- Nessun import da `lib/presentation/`. Possono dipendere da `core/models/`,
  `core/utils/` e dal client Supabase.

## File

| File | Scopo |
|---|---|
| `analytics_service.dart` | Log eventi fire-and-forget sulla tabella `analytics_events`. Nomi snake_case con prefisso area (`auth_*`, `booking_*`, `location_*`, `club_*`). |
| `auth_service.dart` | Singleton inizializzato in `main.dart`. Ascolta `onAuthStateChange` di Supabase Auth: su logout / sessione persa reindirizza automaticamente a `authenticationScreen`. Espone `isLoggedIn`, `currentSession`, `signOut()`. |
| `badge_service.dart` | Singleton con `ValueNotifier<int>` per il badge delle notifiche nella bottom bar. |
| `booking_service.dart` | CRUD prevendite e prenotazioni tavolo. Chiama `NotificationService` quando serve notificare l'utente. |
| `club_service.dart` | Fetch dei locali e delle serate dal DB, con JOIN su `citta` per fallback coordinate. |
| `location_service.dart` | Risoluzione posizione utente: GPS, città manuale, fallback su `shared_preferences`. Espone anche flag persistenti (`isGpsForced`). |
| `navigator_service.dart` | Wrapper sulla `GlobalKey<NavigatorState>` per navigare senza `BuildContext`. Inizializzato in `main.dart`. |
| `notification_service.dart` | Lettura/scrittura notifiche dell'utente su Supabase. Cachea l'ultimo accesso su `shared_preferences`. |
| `orders_service.dart` | Lettura ordini (prevendite + tavoli) dell'utente per la schermata "I miei ordini". |
| `register_service.dart` | Registrazione atomica utente + telefono (E.164) via RPC `register_user_transaction`. Risolve il paese da ISO e calcola `maggiorenne` lato DB. |
| `user_profile_manager.dart` | Singleton sul profilo utente in `public.utenti`: controllo completezza, raggio km, upsert da metadata dopo login OAuth. |
