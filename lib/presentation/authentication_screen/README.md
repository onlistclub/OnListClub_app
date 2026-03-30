# AuthenticationScreen — Schermata di Login

## Cosa fa

È la **prima schermata** che vede l'utente. Permette di:
- Accedere con **email e password**
- Accedere con **Google**
- Accedere con **Apple** (solo su iPhone)
- Andare alla schermata di registrazione

---

## File coinvolti

```
authentication_screen/
├── authentication_screen.dart       <- UI della schermata
├── bloc/
│   ├── authentication_bloc.dart     <- logica: gestisce login e OAuth
│   ├── authentication_event.dart    <- eventi possibili (es. login, Google)
│   └── authentication_state.dart   <- stato corrente (loading, errore, successo)
└── models/
    └── authentication_model.dart   <- dati del form (email, password)
```

---

## Come funziona (flusso)

```
Utente inserisce email + password
        |
        v
Tap su "Accedi"
        |
        v
[AuthenticationBloc] riceve LoginButtonPressedEvent
        |
        v
Supabase: signInWithPassword(email, password)
        |
   |----+-----|
   |          |
successo    errore
   |          |
   v          v
UserProfileManager     SnackBar con messaggio
.ensureProfileExists()
   |
   v
Controlla se mostrare
la schermata GPS
   |
   +--> SI: LocationPermissionScreen
   +--> NO: EventDetailScreen (Home)
```

---

## Logica del BLoC

Il BLoC `AuthenticationBloc` gestisce tre tipi di login:

### 1. Login con email/password
```dart
// authentication_bloc.dart
await client.auth.signInWithPassword(email: email, password: password);
await UserProfileManager().ensureProfileExists();
emit(state.copyWith(isLoginSuccess: true));
```

### 2. Login con Google
```dart
// Usa google_sign_in + Supabase OAuth
await GoogleSignIn().signIn();
await client.auth.signInWithIdToken(provider: OAuthProvider.google, ...);
```

### 3. Login con Apple
```dart
// Solo su iOS, usa sign_in_with_apple
// Poi passa il token a Supabase
```

---

## Dettagli dell'UI

**Sfondo:** gradiente verticale blu scuro `#1600BC → #0E0066 → #050024`

**Campo email:** `TextFormField` con validazione regex per formato email

**Campo password:** Widget separato `_PasswordField` (StatefulWidget) che gestisce la visibilità della password con l'icona occhio

**Pulsante "Accedi":** bianco con testo nero. Prima di mandare l'evento al BLoC, viene validato il form con `state.formKey?.currentState?.validate()`

**Pulsante "Registrati":** navigazione a `SignUpScreen`

**Pulsante Google:** widget `_OAuthButton` con logo Google disegnato tramite `CustomPaint` (nessuna immagine esterna)

**Pulsante Apple:** visibile solo su iOS (`defaultTargetPlatform == TargetPlatform.iOS`)

**Loading state:** mentre il login è in corso, i pulsanti OAuth vengono sostituiti da un `CircularProgressIndicator`

---

## Navigazione dopo il login

Il `BlocConsumer` ascolta i cambiamenti di stato:

```dart
if (state.isLoginSuccess) {
  // Controlla se l'utente ha già impostato la posizione
  LocationService.shouldShowLocationPrompt().then((show) {
    NavigatorService.pushNamedAndRemoveUntil(
      show ? AppRoutes.locationPermissionScreen : AppRoutes.eventDetailScreen,
    );
  });
}

if (state.needsProfileCompletion) {
  // Utente OAuth senza nome/cognome: vai a CompleteProfile
  NavigatorService.pushNamed(AppRoutes.completeProfileScreen, arguments: {...});
}
```

`pushNamedAndRemoveUntil` rimuove tutte le schermate precedenti dallo stack, così l'utente non può tornare indietro al login con il pulsante Back.

---

## Validazione form

| Campo | Regola |
|---|---|
| Email | Non vuota + formato `xxx@xxx.xx` |
| Password | Non vuota + almeno 6 caratteri |
