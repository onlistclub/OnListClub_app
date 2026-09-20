-- =============================================================================
-- OnList Club — Aggiunta timestamp check-in alle prenotazioni (006)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
--
-- Aggiunge la colonna `checked_in_at` alla tabella `prenotazioni` per tracciare
-- esattamente quando viene fatto il check-in (sia manuale sia tramite QR code).
-- Aggiorna anche la vista `v_prenotazioni_dashboard` e la funzione `scan_ticket`.
-- =============================================================================

-- 1. Aggiungi la colonna checked_in_at a public.prenotazioni
ALTER TABLE public.prenotazioni ADD COLUMN IF NOT EXISTS checked_in_at timestamptz;

COMMENT ON COLUMN public.prenotazioni.checked_in_at IS
  'Timestamp di quando è stato effettuato il check-in dell''ospite (manuale o QR).';

-- 2. Aggiorna la funzione scan_ticket per registrare checked_in_at al momento dello scan valido
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
          'scannedAt',  coalesce(v_first_scan, now()),
          'eventName',  v_pp_row.evento_nome
        )
      );
    END;
  END IF;

  -- Biglietto valido e non ancora confermato → marca come confermato e registra checked_in_at
  UPDATE public.prenotazioni
  SET stato         = 'confermata',
      checked_in_at = now(),
      updated_at    = now()
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
      'scannedAt',  now(),
      'eventName',  v_pp_row.evento_nome
    )
  );

END;
$function$;

-- 3. Aggiorna la vista v_prenotazioni_dashboard per usare direttamente checked_in_at
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
    -- Se checked_in_at è NULL ma lo stato è confermata, fa fallback sul primo log di scan
    COALESCE(
      pren.checked_in_at,
      (
        SELECT MIN(sl.scanned_at)
        FROM public.scan_logs sl
        WHERE sl.ticket_id = pp.id AND sl.status_result = 'VALID'
      )
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
  'Vista per la dashboard: unisce checked_in_at come primo_check_in_at per mostrare l''orario di ingresso reale (sia manuale sia QR).';
