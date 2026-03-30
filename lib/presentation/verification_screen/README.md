# VerificationScreen — Schermata di Verifica Email

## Cosa fa

Dopo la registrazione, Supabase invia automaticamente un'email di conferma all'utente.
Questa schermata:
- Informa l'utente che deve cliccare il link nell'email
- Mostra un **countdown** che scade dopo 24 ore
- Permette di **rinviare l'email** se non è arrivata
- Ha un pulsante "**Accedi**" che verifica se l'email è stata confermata
- Reindirizza al login se il tempo scade (`VerificationFailureScreen`)

---

## File coinvolti

```
verification_screen/
├── verification_screen.dart         <- UI della schermata
└── bloc/
    ├── verification_bloc.dart       <- logica: timer, controllo verifica, reinvio
    ├── verification_event.dart      <- eventi (inizializzazione, check, reinvio)
    └── verification_state.dart     <- stato (timer, isVerified, isExpired, errori)
```

---

## Come funziona (flusso)

```
Arrivo dalla SignUpScreen con email + password + registrationTime
        |
        v
[verificationBloc] inizializzato con verificationInitialEvent
        |
        v
Avvia un timer periodico (ogni secondo)
        |
        v
Aggiorna remainingTime (24 ore - tempo trascorso)
        |
        +-- tempo scaduto --> isExpired = true --> VerificationFailureScreen
        |
Utente clicca "Accedi"
        |
        v
[verificationBloc] riceve CheckVerificationEvent
        |
        v
Supabase: signInWithPassword(email, password)
        |
   |----+-----|
   |          |
successo    errore "email non verificata"
   |          |
   v          v
UserProfileManager  Dialog informativo
.ensureProfileExists()
   |
   v
LocationService.shouldShowLocationPrompt()
   |
   +--> Home o LocationPermissionScreen
```

---

## Logica del BLoC

### Timer countdown
Il BLoC avvia un `Timer.periodic` ogni secondo per aggiornare il tempo rimanente:
```dart
// verification_bloc.dart
_timer = Timer.periodic(Duration(seconds: 1), (_) {
  final elapsed = DateTime.now().difference(state.registrationTime!);
  final remaining = Duration(hours: 24) - elapsed;
  if (remaining <= Duration.zero) {
    emit(state.copyWith(isExpired: true));
    _timer?.cancel();
  } else {
    emit(state.copyWith(remainingTime: remaining));
  }
});
```

### Verifica email
Non esiste una chiamata diretta per controllare se l'email è stata verificata. La tecnica usata è tentare un **login**: se Supabase accetta, vuol dire che l'email è stata confermata.
```dart
final response = await client.auth.signInWithPassword(email: email, password: password);
if (response.user != null && response.session != null) {
  await UserProfileManager().ensureProfileExists();
  emit(state.copyWith(isVerified: true));
}
```

### Reinvio email
```dart
await client.auth.resend(type: OtpType.signup, email: state.email!);
emit(state.copyWith(emailResentMessage: "Email inviata!"));
```

---

## Dettagli dell'UI

**Sfondo:** blu brillante `#0000FF` (colore brand)

**Countdown:** formato `HH:MM:SS`, calcolato da `remainingTime`:
```dart
final timerText =
  '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
```

**Pulsante "Accedi":** avvia la verifica. Durante il caricamento mostra `CircularProgressIndicator`.

**Link reinvio:** `TextButton` con testo sottolineato. Quando viene premuto e il BLoC risponde con `emailResentMessage`, appare una SnackBar verde.

**Dialog errore email non verificata:** se Supabase rifiuta il login con messaggio specifico `"Verifica prima l'email"`, viene mostrato un `AlertDialog` invece della solita SnackBar.

**Pulsante "Torna al login":** in fondo alla schermata, usa `pushNamedAndRemoveUntil` per tornare alla schermata di login ripulendo lo stack.

---

## Argomenti in ingresso

La schermata riceve questi dati dalla `SignUpScreen` via `ModalRoute.settings.arguments`:

| Argomento | Tipo | Uso |
|---|---|---|
| `registrationTime` | `DateTime` | Per calcolare il tempo rimanente del countdown |
| `email` | `String` | Per il tentativo di login alla verifica |
| `password` | `String` | Per il tentativo di login alla verifica |
