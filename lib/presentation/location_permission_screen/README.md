# LocationPermissionScreen — Permesso Posizione GPS

## Cosa fa

Appare la **prima volta** che un utente accede all'app, dopo il login o la verifica email.
Spiega perché l'app ha bisogno della posizione e offre due scelte:
- **Apri Impostazioni** — porta alle impostazioni del sistema operativo per abilitare il GPS
- **Ricordamelo più tardi** — salta per ora, porta alla selezione manuale della città

---

## File coinvolti

```
location_permission_screen/
├── location_permission_screen.dart       <- UI della schermata
└── bloc/
    ├── location_permission_bloc.dart     <- logica: controllo GPS, navigazione
    ├── location_permission_event.dart    <- eventi (inizializzazione, apri impostazioni, più tardi)
    └── location_permission_state.dart   <- stato (loading, permesso concesso, vai a manuale)
```

---

## Quando viene mostrata

Non viene mostrata ad ogni accesso, solo quando è necessario. Il controllo avviene in due punti:
- `AuthenticationScreen` dopo il login
- `VerificationScreen` dopo la verifica email

```dart
// In entrambe le schermate:
LocationService.shouldShowLocationPrompt().then((show) {
  NavigatorService.pushNamedAndRemoveUntil(
    show ? AppRoutes.locationPermissionScreen : AppRoutes.eventDetailScreen,
  );
});
```

`shouldShowLocationPrompt()` controlla se il permesso GPS non è ancora stato gestito (né concesso né rifiutato).

---

## Come funziona (flusso)

```
Schermata caricata
        |
        v
[LocationPermissionBloc] riceve LocationPermissionInitialEvent
        |
        v
Controlla lo stato attuale del permesso GPS
        |
        +-- già concesso --> EventDetailScreen (salta questa schermata)
        |
        v
Utente vede la schermata

--- Percorso A: Apri Impostazioni ---
Tap su "Apri Impostazioni"
        |
        v
[LocationPermissionBloc] riceve OpenSettingsEvent
        |
        v
Apre le impostazioni di sistema
        |
        v
Polling: controlla ogni secondo se il permesso è stato abilitato
        |
        +-- permesso concesso --> EventDetailScreen

--- Percorso B: Più tardi ---
Tap su "Ricordamelo più tardi"
        |
        v
[LocationPermissionBloc] riceve RemindLaterEvent
        |
        v
Salva preferenza (non chiedere più ora) in SharedPreferences
        |
        v
goToManualEntry = true --> LocationManualScreen
```

---

## Logica del BLoC

### OpenSettingsEvent
Apre le impostazioni native del dispositivo con `geolocator`:
```dart
// location_permission_bloc.dart
await Geolocator.openLocationSettings();
// Poi ascolta i cambiamenti di permesso con un Stream
```

### RemindLaterEvent
Registra che l'utente ha scelto "più tardi" in `SharedPreferences`, così la schermata non comparirà al prossimo accesso (fino al prossimo ciclo stabilito dalla logica di `shouldShowLocationPrompt`).

---

## Dettagli dell'UI

**Sfondo:** blu brillante `#0000FF`

**Icona GPS:** cerchio scuro con `Icons.location_on` al centro

**Testo sicurezza:** in fondo alla schermata, con lucchetto, rassicura l'utente che la posizione non viene condivisa con terzi

**Pulsante "Apri Impostazioni":** sfondo scuro, bordi arrotondati. Disabilitato durante il caricamento.

**Pulsante "Ricordamelo più tardi":** outlined, bordo bianco

**Loading:** i pulsanti vengono disabilitati e compare un piccolo `CircularProgressIndicator` mentre l'app attende risposta dal sistema

---

## Note importanti

Questa schermata **non richiede direttamente il permesso** con il dialogo nativo del sistema — porta l'utente nelle impostazioni. Questo approccio viene usato quando l'app ha già chiesto il permesso in precedenza e l'utente lo ha negato (in quel caso, il dialogo nativo non riappare automaticamente).
