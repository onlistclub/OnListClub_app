# Post-MVP — Autenticazione / verifica via numero di telefono (app ufficiale)

> **Stato:** rimandato a DOPO il lancio dell'MVP. Per l'app ufficiale.
> **Contesto MVP:** il numero di telefono viene **raccolto** in registrazione e
> salvato in `public.utenti_numeri_telefono` (formato E.164, via RPC
> `register_user_transaction`), ma **non viene verificato**: il campo
> `is_verified` resta sempre `false`. L'autenticazione MVP è
> email/password + Google + Apple.

## Stato attuale (verificato)

- Supabase Auth: provider **phone DISABILITATO** (`/auth/v1/settings` →
  `"phone": false`, `"phone_autoconfirm": false`). Risulta impostato
  `"sms_provider": "twilio"` ma il canale phone non è attivo.
- Tabella `utenti_numeri_telefono`: colonne `telefono` (E.164), `country_id`,
  `is_primary`, `is_verified` (oggi sempre `false`), `created_at`.
- Telefono coerente con la bandiera/paese scelti (fix MVP del selettore in
  registrazione) e scrittura solo via RPC `register_user_transaction`.

## Obiettivo della feature

Due possibili livelli (da decidere):
1. **Verifica del numero** (consigliato come primo passo): l'utente conferma il
   proprio telefono via **SMS OTP**, valorizzando `is_verified = true`. L'auth
   primaria resta email/social.
2. **Login con numero di telefono**: consentire registrazione/accesso usando il
   telefono come credenziale (OTP via SMS), in alternativa all'email.

## Task da fare (DOPO l'MVP)

### 1. Provider SMS / Supabase
- [ ] Scegliere e configurare un provider SMS su Supabase (Twilio o
      alternative) in **Auth → Providers → Phone**: SID, token, mittente.
- [ ] Abilitare il canale phone (`GOTRUE_EXTERNAL`/dashboard) e impostare la
      scadenza OTP.
- [ ] Valutare **costi SMS** e rate limit (gli SMS costano: definire un budget e
      limiti anti-abuso).

### 2. Flusso "verifica numero" (livello 1)
- [ ] Dopo registrazione/login, schermata di inserimento OTP ricevuto via SMS.
- [ ] `supabase.auth.verifyOTP` (type phone) oppure flusso dedicato; al successo
      aggiornare `utenti_numeri_telefono.is_verified = true` (via RPC dedicata
      `SECURITY DEFINER`, coerente con l'architettura attuale).
- [ ] Gestione reinvio OTP con cooldown + rate limit.
- [ ] Stati UI: invio, attesa, errore, scaduto (riusare il pattern della
      verifica email).

### 3. Flusso "login con telefono" (livello 2, opzionale)
- [ ] `signInWithOtp({phone})` + `verifyOTP`.
- [ ] Gestire l'utente che ha sia email che telefono (collegamento identità).
- [ ] Decidere se il telefono diventa credenziale alternativa o secondo fattore.

### 4. Sicurezza / anti-abuso
- [ ] Rate limit invio OTP per numero/IP.
- [ ] Riusare/estendere la RPC `check_registration_availability` per evitare
      doppioni (telefono già verificato da altro account).
- [ ] Considerare il vincolo UNIQUE globale su `telefono` (già previsto nei
      paletti registrazione MVP) come rete di sicurezza.

### 5. Validazione numeri
- [ ] Validare i numeri E.164 lato server (lunghezza/paese) prima dell'invio SMS,
      per non sprecare SMS su numeri non validi.

## Note
- Mantenere **design system** e **sistema responsive** invariati.
- Riusare i pattern già presenti (BLoC per-schermata, RPC SECURITY DEFINER,
  gestione stati loading/errore/vuoto).
