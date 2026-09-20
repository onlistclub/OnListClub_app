-- =============================================================================
-- OnList Club — v_prenotazioni_dashboard smette di bypassare la RLS (012)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
-- DOPO la 011 (che ridefinisce la vista) e PRIMA di pubblicare l'app.
--
-- IL PROBLEMA
-- 2026-05-30_phaseA_critici.sql (punto A3) ha messo security_invoker = true su
-- v_utenti_profilo, v_eventi_dashboard e v_analytics_details. In quell'elenco
-- v_prenotazioni_dashboard non c'era: è rimasta l'unica vista che gira ancora
-- come SECURITY DEFINER, cioè che legge le tabelle sottostanti con i permessi
-- del proprietario e non con quelli di chi interroga.
--
-- Quella vista contiene nome, cognome e data di nascita di ogni acquirente,
-- con serata e locale. Finché è definer, QUALSIASI utente `authenticated` —
-- e dal giorno del lancio significa qualsiasi persona che si scarica l'app e
-- si registra — può leggerla via PostgREST e portarsi via l'anagrafica di
-- tutti i clienti di tutti i locali:
--     curl "$SUPABASE_URL/rest/v1/v_prenotazioni_dashboard?select=*" \
--          -H "apikey: <anon>" -H "Authorization: Bearer <jwt di un utente>"
--
-- PERCHÉ NON BASTA GIRARE L'INTERRUTTORE
-- Il gestionale (Sito_Web_OnListClub_MVP) interroga la vista con la chiave
-- publishable + il JWT del gestore (src/integrations/supabase/auth-middleware.ts),
-- quindi soggetto a RLS. E su `prenotazioni`, `prenotazioni_prevendite` e
-- `prevendite` NON esiste nessuna policy per gestori e staff: le uniche SELECT
-- sono `auth.uid() = id_utente`, cioè l'acquirente. Il gestionale funziona
-- OGGI solo perché la vista scavalca la RLS. Mettere security_invoker senza
-- altro avrebbe svuotato dashboard, scanner e storico.
--
-- Quindi prima le policy, poi l'interruttore. Nello stesso ordine, qui sotto.
--
-- `my_club_id()` copre sia i gestori sia lo staff dalla 007, quindi le policy
-- valgono per entrambi i ruoli che il gestionale accetta (assertGestore).
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. prenotazioni — il gestore legge gli ordini delle SUE serate
--
-- Il legame col locale passa da eventi.club_id: `prenotazioni` non ha un
-- club_id proprio. La policy si aggiunge a quelle esistenti dell'utente
-- (le policy in RLS sono in OR): l'acquirente continua a vedere le proprie.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS gestori_select_prenotazioni ON public.prenotazioni;
CREATE POLICY gestori_select_prenotazioni ON public.prenotazioni
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.eventi e
      WHERE e.id = prenotazioni.id_evento
        AND e.club_id = public.my_club_id()
    )
  );

COMMENT ON POLICY gestori_select_prenotazioni ON public.prenotazioni IS
  'Gestori e staff leggono gli ordini delle serate del proprio locale (via eventi.club_id).';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. prenotazioni_prevendite — leggere i biglietti e timbrarli
--
-- L'UPDATE non è un extra: dalla 011 il check-in si scrive qui
-- (`checked_in_at`), sia dallo scanner sia dal check-in manuale della
-- dashboard, e senza policy Postgres scarterebbe la scrittura in silenzio —
-- zero righe aggiornate, nessun errore, il biglietto che non risulta mai
-- entrato. È lo stesso inciampo del commit 677be61 sui scan_logs.
--
-- WITH CHECK identico alla USING: un gestore non può spostare un biglietto
-- sotto una serata di un altro locale.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS gestori_select_prenotazioni_prevendite ON public.prenotazioni_prevendite;
CREATE POLICY gestori_select_prenotazioni_prevendite ON public.prenotazioni_prevendite
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.prenotazioni pr
      JOIN public.eventi e ON e.id = pr.id_evento
      WHERE pr.id = prenotazioni_prevendite.id_prenotazione
        AND e.club_id = public.my_club_id()
    )
  );

DROP POLICY IF EXISTS gestori_update_checkin ON public.prenotazioni_prevendite;
CREATE POLICY gestori_update_checkin ON public.prenotazioni_prevendite
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.prenotazioni pr
      JOIN public.eventi e ON e.id = pr.id_evento
      WHERE pr.id = prenotazioni_prevendite.id_prenotazione
        AND e.club_id = public.my_club_id()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.prenotazioni pr
      JOIN public.eventi e ON e.id = pr.id_evento
      WHERE pr.id = prenotazioni_prevendite.id_prenotazione
        AND e.club_id = public.my_club_id()
    )
  );

COMMENT ON POLICY gestori_update_checkin ON public.prenotazioni_prevendite IS
  'Gestori e staff timbrano il check-in dei biglietti delle proprie serate (scanner QR e check-in manuale).';

-- La RLS su questa tabella è la sola cosa che, dopo l'interruttore del punto 4,
-- tiene i dati anagrafici lontani dagli utenti dell'app. Se fosse disattivata
-- la vista tornerebbe leggibile da tutti anche da invoker.
-- Sicura da eseguire: le policy dell'utente (SELECT/INSERT sulle proprie righe)
-- esistono già, l'acquisto dall'app continua a passare.
ALTER TABLE public.prenotazioni_prevendite ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. prevendite — la vista ci prende tipo e prezzo del biglietto
--
-- Nessun dato personale qui dentro, quindi NON tocchiamo l'interruttore RLS di
-- questa tabella: attivarla senza sapere quali policy pubbliche esistono
-- rischierebbe di far sparire il listino biglietti dall'app. Aggiungiamo solo
-- la policy del gestore, che se la RLS è spenta è semplicemente inerte.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS gestori_select_prevendite ON public.prevendite;
CREATE POLICY gestori_select_prevendite ON public.prevendite
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.eventi e
      WHERE e.id = prevendite.id_evento
        AND e.club_id = public.my_club_id()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. L'interruttore
-- ─────────────────────────────────────────────────────────────────────────────
ALTER VIEW public.v_prenotazioni_dashboard SET (security_invoker = true);

COMMENT ON VIEW public.v_prenotazioni_dashboard IS
  'Una riga per BIGLIETTO. primo_check_in_at è l''ingresso di quel biglietto, non dell''ordine. security_invoker: ognuno vede solo ciò che la RLS gli concede — il gestore le serate del suo locale, l''utente i propri biglietti.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Un visitatore non autenticato non ha niente da fare qui
--
-- Con la vista definer, un GRANT ad `anon` avrebbe significato anagrafiche
-- leggibili con la sola chiave pubblica del sito. Revocare è a costo zero:
-- il gestionale interroga sempre con il JWT del gestore, mai da anonimo.
-- ─────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON public.v_prenotazioni_dashboard FROM anon;
GRANT SELECT ON public.v_prenotazioni_dashboard TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Verifiche post-applicazione — falle TUTTE prima di considerare chiuso il punto
-- =============================================================================
-- 1) La vista è invoker e la RLS è accesa dove serve:
--    SELECT relname, reloptions FROM pg_class
--    WHERE relkind = 'v' AND relname = 'v_prenotazioni_dashboard';
--    -> reloptions contiene {security_invoker=true}
--
--    SELECT relname, relrowsecurity FROM pg_class
--    WHERE relname IN ('prenotazioni', 'prenotazioni_prevendite');
--    -> relrowsecurity = true su entrambe
--
-- 2) Il buco è chiuso. Con il JWT di un utente NORMALE dell'app:
--    curl "$SUPABASE_URL/rest/v1/v_prenotazioni_dashboard?select=nome,cognome&limit=5" \
--         -H "apikey: <publishable>" -H "Authorization: Bearer <jwt utente app>"
--    -> prima: le anagrafiche di tutti. Adesso: solo i suoi biglietti (o []).
--
-- 3) Il gestionale non si è svuotato. Con il JWT di un GESTORE, e poi con
--    quello di un account STAFF (il ruolo che my_club_id() copre solo dalla 007
--    in poi — se la 007 non fosse mai stata applicata, lo staff vedrebbe una
--    dashboard vuota e questo è il momento in cui te ne accorgi):
--    - /dashboard mostra le prevendite della serata;
--    - /storico mostra lo storico;
--    - lo scanner accetta un biglietto e il check-in resta scritto.
--
-- 4) Il check-in adesso si scrive davvero (prima l'UPDATE veniva scartato):
--    dopo una scansione valida,
--    SELECT checked_in_at FROM public.prenotazioni_prevendite WHERE id = '<biglietto>';
--    -> valorizzato. Se resta NULL, la policy del punto 2 non è attiva.
--
-- =============================================================================
-- Rimasto fuori di proposito
-- =============================================================================
-- Il pulsante "Elimina prevendita" della dashboard (deletePrenotazionePrevendita)
-- fa UPDATE prenotazioni SET stato = 'annullata', e su `prenotazioni` non
-- esiste NESSUNA policy di UPDATE: oggi quel pulsante non annulla niente e non
-- dice niente (stesso motivo per cui esiste la RPC annulla_prevendita lato app,
-- vedi docs/database/migration_annulla_prevendita.sql).
--
-- Non lo sistemo qui perché "un gestore può annullare l'ordine di un cliente"
-- è una decisione tua, non una svista da tappare: una policy di UPDATE su
-- `prenotazioni` gli lascerebbe modificare anche prezzo_totale e n_persone,
-- visto che la RLS lavora per riga e non per colonna. Se la vuoi, la strada
-- pulita è una RPC SECURITY DEFINER `annulla_prevendita_gestore(uuid)` che
-- tocchi solo `stato` e solo per le serate del proprio locale.
