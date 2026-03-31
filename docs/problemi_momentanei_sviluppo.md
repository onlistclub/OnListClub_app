# Problemi Momentanei di Sviluppo
> Ultimo aggiornamento: 31 marzo 2026

Elenco dei bug e limitazioni tecniche attualmente aperte. Da risolvere prima del rilascio MVP.

---

## 🔴 Critici (bloccanti per l'MVP)

### 1. Richiesta GPS ad ogni avvio
**Problema:** La schermata di richiesta permesso GPS viene mostrata ogni volta che si entra nell'app, anche se il permesso era già stato concesso in precedenza.
**File coinvolti:** `lib/core/services/location_service.dart`, `lib/presentation/location_permission_screen/`
**Causa probabile:** La posizione non viene salvata in cache locale (es. `SharedPreferences`) tra una sessione e l'altra. Il permesso viene richiesto nuovamente invece di essere verificato solo se scaduto/revocato.
**Soluzione attesa:** Salvare l'ultima posizione nota e lo stato del permesso in `SharedPreferences`; chiedere GPS solo al primo avvio o se il permesso risulta revocato.

---

### 2. OAuth Google e Apple non configurati
**Problema:** Il login/registrazione tramite Google e Apple non è operativo.
**Dettaglio:**
- **Google OAuth:** mancano le credenziali corrette (`google-services.json` per Android, `GoogleService-Info.plist` per iOS) e la configurazione nel pannello Supabase Auth.
- **Apple OAuth:** richiede obbligatoriamente **Xcode e Mac** per la configurazione del capability `Sign in with Apple` nel progetto iOS, oltre a un Apple Developer Account attivo.
**File coinvolti:** `lib/presentation/authentication_screen/bloc/authentication_bloc.dart`
**Dipendenza esterna:** Accesso a Mac + Xcode per la parte Apple.

---

### 3. Ricerca club non filtra per raggio reale
**Problema:** La schermata dei club vicini (`nearby_clubs_screen.dart`) non restituisce i club effettivamente nel raggio impostato dall'utente — probabilmente mostra tutti i club o nessuno.
**File coinvolti:** `lib/core/services/club_service.dart`, `lib/core/models/locale_model.dart`
**Causa probabile:** La query Supabase non utilizza un filtro geospaziale (es. formula haversine o PostGIS) basato sulla posizione dell'utente e sul raggio scelto.
**Soluzione attesa:** Implementare il filtraggio per distanza lato Supabase (RPC con PostGIS o calcolo haversine in edge function).

---

### 4. Raggio di ricerca non eliminabile
**Problema:** Una volta impostato un raggio di ricerca personalizzato, non è possibile rimuoverlo o resettarlo al valore di default.
**File coinvolti:** `lib/presentation/location_manual_screen/`, `lib/presentation/nearby_clubs_screen/`
**Soluzione attesa:** Aggiungere un pulsante "Reset" o "Rimuovi filtro raggio" che riporti al comportamento di default.

---

## 🟡 Importanti (impattano UX ma non bloccanti)

### 5. Sezione "Questa sera" duplicata nella Home
**Problema:** Il titolo/sezione "Questa sera" appare più volte nella schermata Home, rendendo l'interfaccia ripetitiva e confusa.
**File coinvolti:** `lib/presentation/home_screen/home_screen.dart`, `lib/presentation/home_screen/bloc/home_bloc.dart`
**Causa probabile:** La lista degli eventi viene aggiunta più volte alla UI (possibile doppio trigger del BLoC o errore nella costruzione dei widget).
**Soluzione attesa:** Verificare che il BLoC emetta lo stato una sola volta e che il widget non replichi le sezioni.

---

### 6. Design dell'app non allineato al design ufficiale
**Problema:** L'attuale implementazione UI si discosta dal design ufficiale (Figma). Colori, spaziature, componenti e layout non corrispondono alle specifiche visive del prodotto.
**File coinvolti:** potenzialmente tutte le schermate in `lib/presentation/`
**Soluzione attesa:** Revisione sistematica di tutte le schermate confrontandole con il Figma ufficiale. Priorità: Home, Club Detail, Event Detail, Booking.

---

## 🔵 Operativi (richiedono risorse/attrezzatura esterna)

### 7. Test su dispositivo reale Android e iOS
**Problema:** L'app non è ancora stata testata su hardware reale — solo su emulatori/simulatori.
**Dettaglio:**
- **Android:** richiede un dispositivo fisico Android e l'abilitazione della modalità sviluppatore. Testabile su Windows con ADB.
- **iOS:** richiede obbligatoriamente un **Mac con Xcode** e un Apple Developer Account per fare il provisioning e installare l'app su un iPhone fisico.
**Impatto:** Alcune funzionalità (GPS reale, permessi, notifiche, OAuth Apple) si comportano diversamente su dispositivo reale rispetto all'emulatore.
**Soluzione attesa:** Pianificare sessione di test su dispositivo fisico per entrambe le piattaforme prima del rilascio MVP.

---

## Legenda priorità
| Colore | Significato |
|---|---|
| 🔴 Critico | Blocca funzionalità core dell'MVP — da risolvere subito |
| 🟡 Importante | Impatta UX significativamente — da risolvere entro aprile |
| 🔵 Operativo | Richiede risorse/accesso esterno — pianificare con anticipo |
