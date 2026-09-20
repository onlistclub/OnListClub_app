-- =============================================================================
-- OnList Club — Supporto gestionale web (004)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
--
-- Aggiunge:
--   1. Fix bug get_gestore_by_codice (clubs → locali)
--   2. Tabella scan_logs (log scansioni QR del sito web staff)
--   3. Funzione scan_ticket (RPC per scansione QR in tempo reale)
--   4. Policy RLS per gestori: lettura prenotazioni, prenotazioni_prevendite,
--      utenti e ordini del proprio club
--   5. Policy RLS per gestori: inserimento/aggiornamento scan_logs
--
-- Il QR code nell'app Flutter codifica:
--   https://onlist.club/verify/<prenotazioni_prevendite.id>
-- Il sito web estrae l'UUID dall'URL e chiama scan_ticket(_qr_code := UUID).
-- =============================================================================


-- =============================================================================
-- 1. FIX BUG get_gestore_by_codice (referenziava public.clubs invece di public.locali)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_gestore_by_codice(p_codice text)
RETURNS TABLE(email text, club_nome text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
    SELECT g.email, l.nome
    FROM public.gestori g
    JOIN public.locali l ON l.id = g.club_id
    WHERE g.codice = p_codice
      AND g.attivo = true
    LIMIT 1;
END;
$function$;

COMMENT ON FUNCTION public.get_gestore_by_codice(text) IS
  'Restituisce email e nome del locale dato il codice gestore. Fix: usa locali invece di clubs.';


-- =============================================================================
-- 2. TABELLA scan_logs — log delle scansioni QR eseguite dallo staff via sito web
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.scan_logs (
  id                   uuid        NOT NULL DEFAULT gen_random_uuid(),
  qr_code              text        NOT NULL,           -- UUID di prenotazioni_prevendite
  scanned_at           timestamptz NOT NULL DEFAULT now(),
  scanned_by_user_id   uuid,                           -- auth.users.id del gestore/staff
  status_result        text        NOT NULL,           -- 'VALID' | 'ALREADY_USED' | 'CANCELLED' | 'NOT_FOUND'
  ticket_id            uuid,                           -- prenotazioni_prevendite.id (se trovato)
  club_id              uuid,                           -- locali.id (per filtrare per club)
  CONSTRAINT scan_logs_pkey PRIMARY KEY (id),
  CONSTRAINT scan_logs_status_check CHECK (
    status_result = ANY (ARRAY['VALID','ALREADY_USED','CANCELLED','NOT_FOUND'])
  ),
  CONSTRAINT scan_logs_scanned_by_fkey FOREIGN KEY (scanned_by_user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT scan_logs_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.locali(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.scan_logs IS
  'Log delle scansioni QR eseguite dallo staff via sito web gestionale';

-- Indici per query frequenti
CREATE INDEX IF NOT EXISTS idx_scan_logs_club_scanned
  ON public.scan_logs USING btree (club_id, scanned_at DESC);
CREATE INDEX IF NOT EXISTS idx_scan_logs_ticket
  ON public.scan_logs USING btree (ticket_id);
CREATE INDEX IF NOT EXISTS idx_scan_logs_scanned_by
  ON public.scan_logs USING btree (scanned_by_user_id);


-- =============================================================================
-- 3. FUNZIONE scan_ticket — RPC atomica per la scansione QR
--
-- Il sito web chiama: supabase.rpc('scan_ticket', { _qr_code: uuid })
-- dove uuid è l'ID di prenotazioni_prevendite estratto dall'URL del QR.
--
-- Logica:
--   a. Cerca prenotazioni_prevendite per id (= _qr_code)
--   b. Se non trovato → NOT_FOUND
--   c. Controlla stato della prenotazione padre
--      - 'annullata'  → CANCELLED
--      - 'confermata' (già scansionata) → ALREADY_USED
--   d. Se trovato e valido → UPDATE prenotazioni.stato = 'confermata',
--      inserisce in scan_logs (VALID), restituisce dati del titolare
-- =============================================================================

CREATE OR REPLACE FUNCTION public.scan_ticket(_qr_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pp_id        uuid;
  v_pp_row       record;
  v_pren_stato   text;
  v_evento_nome  text;
  v_club_id      uuid;
  v_result       json;
BEGIN
  -- Normalizza: accetta sia UUID raw che URL https://onlist.club/verify/<uuid>
  IF _qr_code LIKE 'https://%' THEN
    _qr_code := regexp_replace(_qr_code, '^.*/verify/', '');
  END IF;

  -- Valida che sia un UUID valido
  BEGIN
    v_pp_id := _qr_code::uuid;
  EXCEPTION WHEN others THEN
    -- Non è un UUID → NOT_FOUND senza registrare log
    RETURN json_build_object('status', 'NOT_FOUND');
  END;

  -- Cerca la riga in prenotazioni_prevendite
  SELECT
    pp.id,
    pp.nome,
    pp.cognome,
    pp.data_nascita,
    pp.id_prenotazione,
    pp.id_prevendita,
    pp.id_utente,
    pren.stato            AS prenotazione_stato,
    pren.id_evento,
    pv.tipo               AS ticket_tipo,
    e.nome                AS evento_nome,
    e.club_id
  INTO v_pp_row
  FROM public.prenotazioni_prevendite pp
  JOIN public.prenotazioni pren ON pren.id = pp.id_prenotazione
  JOIN public.prevendite   pv   ON pv.id_prevendita = pp.id_prevendita
  JOIN public.eventi       e    ON e.id = pren.id_evento
  WHERE pp.id = v_pp_id
  LIMIT 1;

  IF NOT FOUND THEN
    -- QR non corrisponde a nessun biglietto
    INSERT INTO public.scan_logs (qr_code, status_result, scanned_by_user_id)
    VALUES (_qr_code, 'NOT_FOUND', auth.uid());
    RETURN json_build_object('status', 'NOT_FOUND');
  END IF;

  v_club_id := v_pp_row.club_id;

  -- Controlla stato prenotazione
  IF v_pp_row.prenotazione_stato = 'annullata' THEN
    INSERT INTO public.scan_logs (qr_code, status_result, ticket_id, club_id, scanned_by_user_id)
    VALUES (_qr_code, 'CANCELLED', v_pp_id, v_club_id, auth.uid());
    RETURN json_build_object(
      'status', 'CANCELLED',
      'ticket', json_build_object(
        'id',         v_pp_id,
        'firstName',  v_pp_row.nome,
        'lastName',   v_pp_row.cognome,
        'ticketType', v_pp_row.ticket_tipo,
        'tableLabel', null,
        'notes',      null,
        'scannedAt',  null,
        'eventName',  v_pp_row.evento_nome
      )
    );
  END IF;

  IF v_pp_row.prenotazione_stato = 'confermata' THEN
    -- Già confermata → controlla se questo specifico biglietto era già stato scansionato
    DECLARE
      v_first_scan timestamptz;
    BEGIN
      SELECT scanned_at INTO v_first_scan
      FROM public.scan_logs
      WHERE ticket_id = v_pp_id AND status_result = 'VALID'
      ORDER BY scanned_at ASC
      LIMIT 1;

      INSERT INTO public.scan_logs (qr_code, status_result, ticket_id, club_id, scanned_by_user_id)
      VALUES (_qr_code, 'ALREADY_USED', v_pp_id, v_club_id, auth.uid());

      RETURN json_build_object(
        'status', 'ALREADY_USED',
        'ticket', json_build_object(
          'id',         v_pp_id,
          'firstName',  v_pp_row.nome,
          'lastName',   v_pp_row.cognome,
          'ticketType', v_pp_row.ticket_tipo,
          'tableLabel', null,
          'notes',      null,
          'scannedAt',  v_first_scan,
          'eventName',  v_pp_row.evento_nome
        )
      );
    END;
  END IF;

  -- Biglietto valido e non ancora confermato → marca come confermato
  UPDATE public.prenotazioni
  SET stato      = 'confermata',
      updated_at = now()
  WHERE id = v_pp_row.id_prenotazione
    AND stato <> 'confermata';  -- idempotente

  INSERT INTO public.scan_logs (qr_code, status_result, ticket_id, club_id, scanned_by_user_id)
  VALUES (_qr_code, 'VALID', v_pp_id, v_club_id, auth.uid());

  RETURN json_build_object(
    'status', 'VALID',
    'ticket', json_build_object(
      'id',         v_pp_id,
      'firstName',  v_pp_row.nome,
      'lastName',   v_pp_row.cognome,
      'ticketType', v_pp_row.ticket_tipo,
      'tableLabel', null,
      'notes',      null,
      'scannedAt',  null,
      'eventName',  v_pp_row.evento_nome
    )
  );

END;
$function$;

COMMENT ON FUNCTION public.scan_ticket(text) IS
  'Scansiona un QR code (UUID prenotazioni_prevendite o URL https://onlist.club/verify/<uuid>). '
  'Ritorna JSON con status VALID/ALREADY_USED/CANCELLED/NOT_FOUND e dati del titolare.';


-- =============================================================================
-- 4. RLS su scan_logs
-- =============================================================================

ALTER TABLE public.scan_logs ENABLE ROW LEVEL SECURITY;

-- Gestori vedono solo i log del proprio club
DROP POLICY IF EXISTS gestori_select_scan_logs ON public.scan_logs;
CREATE POLICY gestori_select_scan_logs ON public.scan_logs
  FOR SELECT TO authenticated
  USING (club_id = public.my_club_id());

-- Gestori possono inserire log
DROP POLICY IF EXISTS gestori_insert_scan_logs ON public.scan_logs;
CREATE POLICY gestori_insert_scan_logs ON public.scan_logs
  FOR INSERT TO authenticated
  WITH CHECK (club_id = public.my_club_id());


-- =============================================================================
-- 5. POLICY RLS aggiuntive per il gestionale web
-- =============================================================================

-- ── prenotazioni: gestori leggono quelle del proprio club ────────────────────
DROP POLICY IF EXISTS gestori_select_prenotazioni ON public.prenotazioni;
CREATE POLICY gestori_select_prenotazioni ON public.prenotazioni
  FOR SELECT TO authenticated
  USING (
    id_evento IN (
      SELECT id FROM public.eventi WHERE club_id = public.my_club_id()
    )
  );

-- Gestori possono aggiornare lo stato delle prenotazioni del proprio club
DROP POLICY IF EXISTS gestori_update_prenotazioni ON public.prenotazioni;
CREATE POLICY gestori_update_prenotazioni ON public.prenotazioni
  FOR UPDATE TO authenticated
  USING (
    id_evento IN (
      SELECT id FROM public.eventi WHERE club_id = public.my_club_id()
    )
  )
  WITH CHECK (
    id_evento IN (
      SELECT id FROM public.eventi WHERE club_id = public.my_club_id()
    )
  );

-- ── prenotazioni_prevendite: gestori leggono i biglietti del proprio club ────
DROP POLICY IF EXISTS gestori_select_prenotazioni_prevendite ON public.prenotazioni_prevendite;
CREATE POLICY gestori_select_prenotazioni_prevendite ON public.prenotazioni_prevendite
  FOR SELECT TO authenticated
  USING (
    id_prenotazione IN (
      SELECT p.id FROM public.prenotazioni p
      JOIN public.eventi e ON e.id = p.id_evento
      WHERE e.club_id = public.my_club_id()
    )
  );

-- ── utenti: gestori leggono i profili di chi ha prenotato nel loro club ──────
DROP POLICY IF EXISTS gestori_select_utenti_club ON public.utenti;
CREATE POLICY gestori_select_utenti_club ON public.utenti
  FOR SELECT TO authenticated
  USING (
    id IN (
      SELECT DISTINCT p.id_utente FROM public.prenotazioni p
      JOIN public.eventi e ON e.id = p.id_evento
      WHERE e.club_id = public.my_club_id()
        AND p.id_utente IS NOT NULL
    )
  );

-- ── ordini: gestori leggono gli ordini del proprio club ──────────────────────
DROP POLICY IF EXISTS gestori_select_ordini ON public.ordini;
CREATE POLICY gestori_select_ordini ON public.ordini
  FOR SELECT TO authenticated
  USING (
    id IN (
      SELECT DISTINCT p.id_ordine FROM public.prenotazioni p
      JOIN public.eventi e ON e.id = p.id_evento
      WHERE e.club_id = public.my_club_id()
        AND p.id_ordine IS NOT NULL
    )
  );


-- =============================================================================
-- 6. VIEW per dashboard web gestionale
-- =============================================================================

-- Vista prenotazioni con dettaglio ticket — usata dalla dashboard web
CREATE OR REPLACE VIEW public.v_prenotazioni_dashboard AS
  SELECT
    pp.id                               AS prenotazione_prevendita_id,
    pp.nome,
    pp.cognome,
    pp.data_nascita,
    pren.id                             AS prenotazione_id,
    pren.stato,
    pren.created_at,
    pren.n_persone,
    pren.prezzo_totale,
    pren.id_evento,
    pv.tipo                             AS ticket_tipo,
    pv.prezzo                           AS ticket_prezzo,
    e.nome                              AS evento_nome,
    e.inizio_evento,
    e.club_id,
    l.nome                              AS locale_nome,
    -- Check se questo biglietto è già stato scansionato (prima scansione VALID)
    (
      SELECT MIN(sl.scanned_at)
      FROM public.scan_logs sl
      WHERE sl.ticket_id = pp.id AND sl.status_result = 'VALID'
    )                                   AS primo_check_in_at,
    -- URL del QR code
    'https://onlist.club/verify/' || pp.id::text AS qr_url
  FROM public.prenotazioni_prevendite pp
  JOIN public.prenotazioni pren ON pren.id = pp.id_prenotazione
  JOIN public.prevendite   pv   ON pv.id_prevendita = pp.id_prevendita
  JOIN public.eventi       e    ON e.id = pren.id_evento
  JOIN public.locali       l    ON l.id = e.club_id
  ORDER BY pren.created_at DESC;

COMMENT ON VIEW public.v_prenotazioni_dashboard IS
  'Vista per la dashboard web gestionale: prenotazioni + biglietti + info evento';


-- =============================================================================
-- 7. TRIGGER AUTOMATICO CREAZIONE GESTORE DA AUTH METADATA (Opzione B)
-- =============================================================================

-- Permetti al gestore di essere creato inizialmente senza club assegnato
ALTER TABLE public.gestori ALTER COLUMN club_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.handle_new_gestore()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Controlla se nei metadati dell'utente auth.users è stato specificato il ruolo 'gestore'
  IF (new.raw_user_meta_data->>'role') = 'gestore' THEN
    INSERT INTO public.gestori (id, club_id, codice, nome, ruolo, email, attivo)
    VALUES (
      new.id,
      NULLIF(new.raw_user_meta_data->>'club_id', '')::uuid,     -- Può essere NULL
      coalesce(new.raw_user_meta_data->>'codice', substr(new.id::text, 1, 8)), -- Genera codice di default
      new.raw_user_meta_data->>'nome',
      coalesce(new.raw_user_meta_data->>'ruolo', 'staff'),       -- 'admin' o 'staff'
      new.email,
      true
    );
  END IF;
  RETURN new;
END;
$function$;

-- Elimina il trigger se esiste già
DROP TRIGGER IF EXISTS on_auth_user_created_gestore ON auth.users;

-- Crea il trigger
CREATE TRIGGER on_auth_user_created_gestore
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_gestore();

COMMENT ON FUNCTION public.handle_new_gestore() IS
  'Trigger automatico per inserire un utente in public.gestori se registrato con metadata role=gestore.';


-- =============================================================================
-- FINE migration 004
-- =============================================================================
