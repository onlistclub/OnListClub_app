-- =============================================================================
-- OnList Club — Il check-in torna sul biglietto, non sull'ordine (011)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
--
-- IL PROBLEMA
-- Un acquisto di 3 biglietti crea UNA riga `prenotazioni` e TRE righe
-- `prenotazioni_prevendite` (una per intestatario) — vedi
-- lib/core/services/booking_service.dart. La 006 però ha messo il timestamp di
-- ingresso su `prenotazioni.checked_in_at`, cioè sull'ORDINE, e la vista
-- `v_prenotazioni_dashboard` espone quel campo come `primo_check_in_at`.
-- Conseguenza alla porta: scansionato il primo dei tre biglietti, l'ordine
-- risulta entrato e gli altri due amici vengono respinti come ALREADY_USED.
--
-- Sempre nella 006, `scan_ticket` considera "già usato" qualsiasi biglietto la
-- cui prenotazione sia in stato 'confermata'. Ma `booking_service` scrive
-- 'confermata' GIÀ AL MOMENTO DELL'ACQUISTO: per quella funzione, quindi, ogni
-- biglietto nasce già usato e nessuno entrerebbe.
--
-- LA CORREZIONE
--   1. `prenotazioni_prevendite.checked_in_at` — il check-in appartiene al
--      singolo biglietto, che è l'oggetto che passa dal lettore.
--   2. Backfill dei check-in già avvenuti, letti da `scan_logs` (che è sempre
--      stato per-biglietto e quindi corretto).
--   3. `v_prenotazioni_dashboard.primo_check_in_at` legge la colonna nuova;
--      `prenotazioni.checked_in_at` non viene più consultato.
--   4. `scan_ticket` decide su questo biglietto e non sullo stato dell'ordine.
--   5. `v_eventi_dashboard` guadagna `checkin_effettuati`: il KPI "Check-in"
--      del gestionale contava le prenotazioni 'confermata', cioè i biglietti
--      venduti, non le persone entrate.
--
-- `prenotazioni.checked_in_at` resta in tabella (storico della 006) ma nessuno
-- lo legge più: si può rimuovere in una migration successiva, a lancio fatto.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Il check-in sul biglietto
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.prenotazioni_prevendite
  ADD COLUMN IF NOT EXISTS checked_in_at timestamptz;

COMMENT ON COLUMN public.prenotazioni_prevendite.checked_in_at IS
  'Quando QUESTO biglietto è entrato (scansione QR o check-in manuale). NULL = non ancora entrato. Un ordine da 3 biglietti ha 3 timestamp indipendenti.';

CREATE INDEX IF NOT EXISTS idx_prenotazioni_prevendite_checked_in_at
  ON public.prenotazioni_prevendite (checked_in_at)
  WHERE checked_in_at IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Backfill dai log di scansione
--
-- `scan_logs` ha sempre registrato `ticket_id`, quindi sa per ogni biglietto
-- quando è entrato davvero. È l'unica fonte affidabile: `prenotazioni.checked_in_at`
-- non permette di distinguere quale dei biglietti dell'ordine sia passato, e
-- copiarlo su tutti darebbe per entrata gente rimasta fuori.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public.prenotazioni_prevendite pp
SET checked_in_at = sl.primo_scan
FROM (
  SELECT ticket_id, MIN(scanned_at) AS primo_scan
  FROM public.scan_logs
  WHERE status_result = 'VALID' AND ticket_id IS NOT NULL
  GROUP BY ticket_id
) sl
WHERE sl.ticket_id = pp.id
  AND pp.checked_in_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. La vista delle prenotazioni
--
-- Stesse colonne, stesso ordine della 006 (CREATE OR REPLACE lo pretende):
-- cambia solo COME viene calcolato `primo_check_in_at`. Il fallback su
-- `scan_logs` resta per i biglietti scansionati prima di questa migration nel
-- caso il backfill non li avesse coperti; `prenotazioni.checked_in_at` esce
-- definitivamente dal calcolo.
--
-- `qr_url` allineato al dominio che l'app scrive davvero dentro il QR
-- (www.onlistclub.com, vedi prevendita_detail_screen.dart): onlist.club non
-- risponde e la pagina /verify/<id> vive sul sito.
-- ─────────────────────────────────────────────────────────────────────────────
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
    COALESCE(
      pp.checked_in_at,
      (
        SELECT MIN(sl.scanned_at)
        FROM public.scan_logs sl
        WHERE sl.ticket_id = pp.id AND sl.status_result = 'VALID'
      )
    )                                   AS primo_check_in_at,
    'https://www.onlistclub.com/verify/' || pp.id::text AS qr_url
  FROM public.prenotazioni_prevendite pp
  JOIN public.prenotazioni pren ON pren.id = pp.id_prenotazione
  JOIN public.prevendite   pv   ON pv.id_prevendita = pp.id_prevendita
  JOIN public.eventi       e    ON e.id = pren.id_evento
  JOIN public.locali       l    ON l.id = e.club_id
  ORDER BY pren.created_at DESC;

COMMENT ON VIEW public.v_prenotazioni_dashboard IS
  'Una riga per BIGLIETTO. primo_check_in_at è l''ingresso di quel biglietto, non dell''ordine: i biglietti comprati insieme entrano ognuno per conto proprio.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. scan_ticket
--
-- Decide sul biglietto:
--   NOT_FOUND   → il QR non è un UUID o non corrisponde a nessun biglietto
--   CANCELLED   → l'ordine è stato annullato
--   ALREADY_USED→ QUESTO biglietto è già entrato (checked_in_at valorizzato)
--   VALID       → primo ingresso: timbra il biglietto
--
-- Lo stato dell'ordine non è più un criterio di "già usato": l'app crea le
-- prenotazioni già 'confermata' al momento dell'acquisto.
-- L'UPDATE è idempotente (`AND checked_in_at IS NULL`): due lettori che
-- sparano insieme sullo stesso QR non producono due ingressi validi.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.scan_ticket(_qr_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pp_id        uuid;
  v_pp_row       record;
  v_club_id      uuid;
  v_now          timestamptz;
  v_righe        integer;
BEGIN
  -- Normalizza: accetta l'UUID nudo o l'URL completo, su qualsiasi dominio
  -- (www.onlistclub.com oggi, onlist.club nei QR vecchi).
  IF _qr_code LIKE 'http%' THEN
    _qr_code := regexp_replace(_qr_code, '^.*/verify/', '');
  END IF;
  _qr_code := split_part(_qr_code, '?', 1);

  BEGIN
    v_pp_id := _qr_code::uuid;
  EXCEPTION WHEN others THEN
    RETURN json_build_object('status', 'NOT_FOUND');
  END;

  SELECT
    pp.id,
    pp.nome,
    pp.cognome,
    pp.checked_in_at,
    pp.id_prenotazione,
    pren.stato            AS prenotazione_stato,
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
    INSERT INTO public.scan_logs (qr_code, status_result, scanned_by_user_id)
    VALUES (_qr_code, 'NOT_FOUND', auth.uid());
    RETURN json_build_object('status', 'NOT_FOUND');
  END IF;

  v_club_id := v_pp_row.club_id;

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

  IF v_pp_row.checked_in_at IS NOT NULL THEN
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
        'scannedAt',  v_pp_row.checked_in_at,
        'eventName',  v_pp_row.evento_nome
      )
    );
  END IF;

  v_now := now();

  UPDATE public.prenotazioni_prevendite
  SET checked_in_at = v_now
  WHERE id = v_pp_id
    AND checked_in_at IS NULL;

  GET DIAGNOSTICS v_righe = ROW_COUNT;

  -- Qualcun altro ha timbrato lo stesso biglietto nel frattempo: il primo
  -- lettore ha vinto, questo è un doppione.
  IF v_righe = 0 THEN
    INSERT INTO public.scan_logs (qr_code, status_result, ticket_id, club_id, scanned_by_user_id)
    VALUES (_qr_code, 'ALREADY_USED', v_pp_id, v_club_id, auth.uid());
    RETURN json_build_object('status', 'ALREADY_USED');
  END IF;

  INSERT INTO public.scan_logs (qr_code, status_result, ticket_id, club_id, scanned_by_user_id, scanned_at)
  VALUES (_qr_code, 'VALID', v_pp_id, v_club_id, auth.uid(), v_now);

  RETURN json_build_object(
    'status', 'VALID',
    'ticket', json_build_object(
      'id',         v_pp_id,
      'firstName',  v_pp_row.nome,
      'lastName',   v_pp_row.cognome,
      'ticketType', v_pp_row.ticket_tipo,
      'tableLabel', null,
      'notes',      null,
      'scannedAt',  v_now,
      'eventName',  v_pp_row.evento_nome
    )
  );
END;
$function$;

COMMENT ON FUNCTION public.scan_ticket(text) IS
  'Scansione di UN biglietto. ALREADY_USED guarda prenotazioni_prevendite.checked_in_at, non lo stato dell''ordine.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Il KPI "Check-in" del gestionale
--
-- `prenotazioni_confermate` conta le prenotazioni in stato 'confermata', che
-- l'app scrive all'acquisto: come misura degli ingressi diceva sempre
-- "entrati = venduti". Resta dov'è (la usa l'incasso), ma si aggiunge in coda
-- il conteggio vero delle persone passate dal lettore.
-- Colonna AGGIUNTA IN FONDO: CREATE OR REPLACE VIEW non tollera modifiche
-- all'ordine o al tipo delle colonne esistenti.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_eventi_dashboard AS
SELECT
  e.id              AS evento_id,
  e.nome            AS evento_nome,
  e.inizio_evento,
  e.fine_evento,
  e.stato,
  e.ingressi_previsti,
  e.posti_prenotati,
  e.prezzo_ingresso,
  e.incasso_previsto,
  l.id              AS club_id,
  l.nome            AS club_nome,
  c.nome_citta,
  (SELECT count(*)
   FROM public.prenotazioni pr
   WHERE pr.id_evento = e.id AND pr.stato = 'confermata'
  ) AS prenotazioni_confermate,
  (SELECT COALESCE(sum(pr.prezzo_totale), 0)
   FROM public.prenotazioni pr
   WHERE pr.id_evento = e.id AND pr.stato = 'confermata'
  ) AS incasso_reale,
  (SELECT count(*)
   FROM public.prenotazioni_prevendite pp
   JOIN public.prevendite pv ON pv.id_prevendita = pp.id_prevendita
   WHERE pv.id_evento = e.id
  ) AS biglietti_venduti,
  (SELECT count(*)
   FROM public.prenotazioni_tavolo pt
   WHERE pt.id_evento = e.id AND pt.stato != 'annullata'
  ) AS tavoli_prenotati,
  -- Persone realmente entrate: un biglietto timbrato = una persona.
  (SELECT count(*)
   FROM public.prenotazioni_prevendite pp
   JOIN public.prenotazioni pr ON pr.id = pp.id_prenotazione
   WHERE pr.id_evento = e.id
     AND pr.stato <> 'annullata'
     AND pp.checked_in_at IS NOT NULL
  ) AS checkin_effettuati
FROM public.eventi e
JOIN public.locali l ON l.id = e.club_id
LEFT JOIN public.citta c ON c.id_citta = l.id_citta
ORDER BY e.inizio_evento DESC;

-- CREATE OR REPLACE conserva le reloptions, ma la 009 ha già dovuto ricreare
-- questa view da zero una volta: meglio riaffermarlo che riscoprirlo con un
-- leak di metriche fra locali.
ALTER VIEW public.v_eventi_dashboard SET (security_invoker = true);

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Verifiche post-applicazione
-- =============================================================================
-- 1) Ordini con più biglietti: ogni riga deve avere il PROPRIO check-in.
--    SELECT prenotazione_id, prenotazione_prevendita_id, nome, cognome,
--           primo_check_in_at
--    FROM public.v_prenotazioni_dashboard
--    WHERE prenotazione_id IN (
--      SELECT id_prenotazione FROM public.prenotazioni_prevendite
--      GROUP BY id_prenotazione HAVING count(*) > 1
--    )
--    ORDER BY prenotazione_id;
--    -> dopo aver scansionato UN solo biglietto del gruppo, gli altri devono
--       restare a NULL.
--
-- 2) Il backfill non ha inventato ingressi:
--    SELECT count(*) FROM public.prenotazioni_prevendite WHERE checked_in_at IS NOT NULL;
--    SELECT count(DISTINCT ticket_id) FROM public.scan_logs WHERE status_result='VALID';
--    -> i due numeri devono coincidere.
--
-- 3) Il KPI degli ingressi non è più uguale al venduto:
--    SELECT evento_nome, biglietti_venduti, prenotazioni_confermate, checkin_effettuati
--    FROM public.v_eventi_dashboard WHERE inizio_evento > now() - interval '30 days';
