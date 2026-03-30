# SignUpScreen — Schermata di Registrazione

## Cosa fa

Permette a un nuovo utente di creare un account inserendo:
- Nome e cognome
- Email e password (con conferma)
- Numero di telefono con prefisso internazionale
- Data di nascita (con selezione da calendario)

Al termine mostra un feedback visivo sull'età (maggiorenne / minorenne).

---

## File coinvolti

```
sign_up_screen/
├── sign_up_screen.dart        <- UI del form di registrazione
├── bloc/
│   ├── sign_up_bloc.dart      <- logica: chiama Supabase per creare l'account
│   ├── sign_up_event.dart     <- eventi (cambio campo, submit, ecc.)
│   └── sign_up_state.dart     <- stato (loading, successo, errore, dati form)
└── models/
    └── sign_up_model.dart     <- modello dati del form
```

---

## Come funziona (flusso)

```
Utente compila il form
        |
        v
Tap su "Registrati"
        |
        v
[SignUpBloc] riceve SubmitSignUpEvent
        |
        v
Supabase: auth.signUp(email, password, metadata: {nome, cognome, ...})
        |
   |----+-----|
   |          |
successo    errore
   |          |
   v          v
Naviga a    SnackBar con
Verification  messaggio errore
Screen
```

---

## Logica del BLoC

### Aggiornamento campi
Ogni campo del form invia un evento al BLoC quando cambia:
```dart
context.read<SignUpBloc>().add(EmailChangedEvent(email: value));
context.read<SignUpBloc>().add(PhoneChangedEvent(phone: full, countryIso: iso, nationalNumber: nn));
```
Il BLoC aggiorna il `SignUpModel` dentro lo stato, così i dati sono sempre disponibili al momento del submit.

### Registrazione
```dart
// sign_up_bloc.dart
await client.auth.signUp(
  email: email,
  password: password,
  data: {
    'nome': nome,
    'cognome': cognome,
    'data_nascita': dob,
    'telefono': phone,
    'country_iso': countryIso,
    ...
  },
);
```
I metadati vengono salvati in `auth.users.raw_user_meta_data`. Non vengono scritti subito sulle tabelle pubbliche — questo avviene solo **dopo** la verifica email, tramite la funzione RPC `register_user_transaction`.

---

## Dettagli dell'UI

**Sfondo:** stesso gradiente della schermata di login `#1600BC → indigo → nero`

**Campo telefono:** usa il pacchetto `intl_phone_number_input`. Mostra una dialog per scegliere il prefisso del paese (IT, CH, FR, DE, ES). Quando l'utente scrive il numero, viene separato il prefisso dal numero nazionale:
```dart
final nn = cleaned.startsWith(dialClean)
    ? cleaned.substring(dialClean.length)
    : cleaned;
```

**Data di nascita:** un `GestureDetector` con `AbsorbPointer` apre un `DatePicker` nativo. `AbsorbPointer` impedisce all'utente di digitare la data manualmente, forzando la selezione dal calendario.

**Indicatore età:** dopo la selezione della data, appare un testo colorato:
- Verde: "Utente maggiorenne" (18+)
- Arancione: "Utente minorenne" (14-17)

Calcolato con `AgeCalculator.isAdult()` da [age_calculator.dart](../../core/utils/age_calculator.dart).

**Età minima:** 14 anni. Il validatore blocca la registrazione se l'utente è più giovane.

**Link "Hai già un account?":** in fondo alla schermata, torna al login con `NavigatorService.goBack()`

---

## Navigazione post-registrazione

Quando il BLoC riceve `isSuccess = true`, la schermata naviga a `VerificationScreen` passando:
```dart
{
  'registrationTime': DateTime.now(),  // usato per il countdown
  'email': state.signUpModel?.email,   // usato per il tentativo di login
  'password': state.signUpModel?.password,
}
```

---

## Validazione form

| Campo | Regola |
|---|---|
| Nome | Almeno 2 caratteri |
| Cognome | Almeno 2 caratteri |
| Email | Non vuota + formato valido |
| Password | Almeno 8 caratteri |
| Conferma password | Deve corrispondere alla password |
| Telefono | Campo gestito da `intl_phone_number_input` |
| Data di nascita | Obbligatoria + età minima 14 anni |
