# Come verificare che la welcome email arrivi (Google e Apple)

Questa guida spiega come confermare al 100% che la welcome email parte quando
un utente si registra con Google o Apple. La logica è coperta a codice — questa
è la procedura di verifica manuale con un utente di test reale.

## Come è cablato

Due punti d'invio, entrambi in fire-and-forget con log strutturato:

| Provider | Punto d'invio | Prefisso log |
|---|---|---|
| Email + password | `UserProfileManager.ensureProfileExists` dopo la verifica email | `[UPM][welcome]` |
| Google, Apple, futuri OAuth | `CompleteProfileBloc._onSubmit` dopo `registerAtomic` | `[CompleteProfile][welcome]` |

Entrambi:
- se `user.email` è vuoto stampano `SKIP: user.email vuoto (user.id=...)`
- se `MessagingService.sendWelcomeEmail` ritorna `true` (Brevo ha accettato) stampano `esito=OK`
- se ritorna `false` stampano `esito=FAIL`
- se il Future esplode con un throw stampano `errore=<messaggio>`

`sendWelcomeEmail` non lancia mai eccezioni al chiamante (il try/catch è interno),
quindi il ramo `errore=...` in pratica non si vede — ma è lì per sicurezza se
un domani cambia il comportamento.

## Procedura di verifica

1. Avviare l'app in debug con `flutter run -d <device>` (o `flutter run` con
   il device collegato). Serve il debug perché `debugPrint` non stampa in
   release. In alternativa, usare `adb logcat | grep welcome` su Android o
   il pannello Console di Xcode su iOS in modalità debug.
2. Registrarsi con un **nuovo account** Google (o Apple) mai usato prima
   sull'app di prova. Deve essere nuovo perché la welcome parte una sola volta
   alla creazione del profilo: se il profilo esiste già in `public.utenti`
   `ensureProfileExists` non fa nulla e nessuna welcome parte.
3. Completare il form del `CompleteProfileScreen` (nome/cognome/data di nascita/
   telefono, che Google e Apple non danno) e tap su "Salva".
4. Nel terminale/console dovresti vedere una riga tipo:
   ```
   flutter: [CompleteProfile][welcome] destinatario=nome.cognome@gmail.com nome="Nome Cognome" esito=OK
   ```
   Se vedi `esito=OK` = Brevo ha accettato l'invio. L'email arriva entro pochi
   secondi (Brevo di solito consegna in < 30s).
5. Aprire la casella dell'account di prova, dovresti trovare la welcome col
   layout ZUCC (border viola, mail.png dentro plate #0a0a0a).

## Cosa fare se `esito=FAIL`

`esito=FAIL` significa che la Edge Function `send-email` NON ha risposto con
`{ ok: true }`. Cause tipiche in ordine di frequenza:

- **BREVO_API_KEY assente/scaduta** → in Supabase Dashboard, Functions →
  send-email → Secrets, verificare che `BREVO_API_KEY` sia impostata e valida.
- **BREVO_SENDER_EMAIL non verificato** → il mittente di default è
  `no-reply@onlist.club`. Deve essere un sender verificato in Brevo.
- **Utente non ha JWT valido** → la Edge Function ha `verify_jwt` attivo.
  Se `Supabase.instance.client.auth.currentSession` è null al momento
  dell'invocazione, la function rifiuta. Verifica che l'utente sia loggato
  quando fai submit del profilo.
- **Rate limit Brevo** → account free ha limite giornaliero. Controllare
  la dashboard Brevo (log invii).

## Cosa fare se non si vede nessun log

Se il log `[CompleteProfile][welcome]` non compare, l'invio non è stato
neanche tentato. Cause possibili:

- L'utente ha completato il profilo, ma è entrato dal flusso email+password
  invece che OAuth → guarda i log `[UPM][welcome]` invece.
- L'app è in release build → `debugPrint` è silente. Rilancia in debug.
- Il profilo esisteva già in `public.utenti` → `ensureProfileExists` skippa,
  `CompleteProfileScreen` non viene mostrato. In quel caso non c'è nulla da
  loggare, ed è il comportamento corretto (welcome una sola volta per utente).

## Preparazione Apple

Il codice del `CompleteProfileBloc` è **agnostico rispetto al provider**: non
sa e non gli importa se l'utente arriva da Google, da Apple o da un futuro
provider. Guarda solo `Supabase.instance.client.auth.currentUser` e chiama
`registerAtomic` + welcome. Quindi quando `signInWithApple` verrà accesa in
produzione (configurando Team ID / Key ID / Services ID / .p8 in Supabase
Auth Providers → Apple), la welcome partirà **automaticamente** per gli
utenti Apple con lo stesso codepath testato oggi con Google. Nessuna riga
aggiuntiva da toccare.
