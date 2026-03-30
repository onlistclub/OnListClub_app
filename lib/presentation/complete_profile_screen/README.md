# CompleteProfileScreen — Completa il Profilo

## Cosa fa

Questa schermata compare solo per gli utenti che si registrano tramite **Google o Apple** (OAuth), quando il provider non fornisce tutti i dati necessari (es. numero di telefono o data di nascita).

L'utente deve inserire:
- Nome (pre-compilato se fornito da OAuth)
- Cognome (pre-compilato se fornito da OAuth)
- Numero di telefono con prefisso internazionale
- Data di nascita

---

## File coinvolti

```
complete_profile_screen/
├── complete_profile_screen.dart       <- UI del form
├── bloc/
│   ├── complete_profile_bloc.dart     <- logica: salva profilo su Supabase
│   ├── complete_profile_event.dart    <- eventi (cambio campo, submit, ecc.)
│   └── complete_profile_state.dart   <- stato (loading, successo, dati form)
└── models/
    └── complete_profile_model.dart   <- modello dati del form
```

---

## Quando viene mostrata

Dal `AuthenticationBloc`, dopo un login OAuth, se mancano dati nel profilo:
```dart
// authentication_bloc.dart
if (state.needsProfileCompletion) {
  NavigatorService.pushNamed(
    AppRoutes.completeProfileScreen,
    arguments: {
      'nome': state.oauthNome,     // nome preso da Google/Apple (se disponibile)
      'cognome': state.oauthCognome,
    },
  );
}
```

---

## Come funziona (flusso)

```
Arrivo con nome/cognome pre-compilati (opzionale)
        |
        v
[CompleteProfileBloc] riceve CompleteProfileInitialEvent
        |
        v
Pre-compila i controller con i dati OAuth
        |
        v
Utente compila/corregge i campi mancanti
        |
        v
Tap su "Continua"
        |
        v
[CompleteProfileBloc] riceve CompleteProfileSubmitEvent
        |
        v
Salva dati su Supabase (update users + insert users_phones)
        |
   |----+-----|
   |          |
successo    errore
   |          |
   v          v
EventDetailScreen   SnackBar errore
```

---

## Logica del BLoC

Il BLoC riceve i dati OAuth nel costruttore e pre-popola i controller di testo:
```dart
// complex_profile_bloc.dart
on<CompleteProfileInitialEvent>((event, emit) {
  if (event.prefillNome != null) {
    state.firstNameController?.text = event.prefillNome!;
  }
  if (event.prefillCognome != null) {
    state.lastNameController?.text = event.prefillCognome!;
  }
});
```

Al submit, chiama la stessa funzione RPC usata nella registrazione normale per salvare i dati in modo transazionale.

---

## Dettagli dell'UI

**Struttura visiva:** identica alla `SignUpScreen` — stesso sfondo gradiente, stessi widget `CustomEditText`, stesso selettore telefono e calendario per la data.

**Pre-compilazione:** se nome e cognome arrivano dall'OAuth, i campi sono già compilati. L'utente può modificarli.

**Campo telefono:** `InternationalPhoneNumberInput` con gli stessi paesi di `SignUpScreen` (IT, CH, FR, DE, ES).

**Data di nascita:** `GestureDetector + AbsorbPointer + DatePicker` — identico a `SignUpScreen`. Mostra indicatore verde/arancione maggiorenne/minorenne.

**Pulsante "Continua":** al posto di "Registrati". Porta direttamente alla `EventDetailScreen` (non c'è bisogno di verifica email, l'utente OAuth è già verificato).

---

## Differenza con SignUpScreen

| Aspetto | SignUpScreen | CompleteProfileScreen |
|---|---|---|
| Chi la usa | Utenti nuovi con email | Utenti OAuth (Google/Apple) |
| Campi email/password | Presenti | Non presenti (già gestiti da OAuth) |
| Pre-compilazione | Nessuna | Nome/cognome da OAuth |
| Dopo il submit | Vai a VerificationScreen | Vai direttamente a EventDetailScreen |
