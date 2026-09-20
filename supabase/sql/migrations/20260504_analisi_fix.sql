-- ============================================================================
-- MIGRAZIONE COMPLETA: Fix da Analisi DB OnList — 2026-05-04
-- ============================================================================
-- Eseguire su Supabase SQL Editor in ordine.
-- Ogni sezione è idempotente (IF NOT EXISTS / OR REPLACE).
-- ============================================================================

BEGIN;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 1 — FIX TIPI DI DATO                                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- R6: prenotazioni_tavolo.n_persone è text → deve essere integer
ALTER TABLE public.prenotazioni_tavolo
  ALTER COLUMN n_persone TYPE integer USING NULLIF(n_persone, '')::integer;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 2 — EXTENSION moddatetime                                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 3 — TRIGGER updated_at (R9)                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Utenti
DROP TRIGGER IF EXISTS trg_utenti_updated_at ON public.utenti;
CREATE TRIGGER trg_utenti_updated_at
  BEFORE UPDATE ON public.utenti
  FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- Eventi
DROP TRIGGER IF EXISTS trg_eventi_updated_at ON public.eventi;
CREATE TRIGGER trg_eventi_updated_at
  BEFORE UPDATE ON public.eventi
  FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- Ordini
DROP TRIGGER IF EXISTS trg_ordini_updated_at ON public.ordini;
CREATE TRIGGER trg_ordini_updated_at
  BEFORE UPDATE ON public.ordini
  FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime(updated_at);

-- Prenotazioni
DROP TRIGGER IF EXISTS trg_prenotazioni_updated_at ON public.prenotazioni;
CREATE TRIGGER trg_prenotazioni_updated_at
  BEFORE UPDATE ON public.prenotazioni
  FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime(updated_at);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 4 — FUNCTION my_club_id() (mancante, usata da RLS)          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION public.my_club_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT club_id
  FROM public.gestori
  WHERE id::text = (
    SELECT auth.uid()::text
  )
    AND attivo = true
  LIMIT 1;
$$;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 5 — TRIGGER: Auto-aggiornamento posti_prenotati (R2)        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION public.fn_update_posti_prenotati()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_evento_id uuid;
  v_count     integer;
BEGIN
  -- Determina l'evento coinvolto (INSERT/UPDATE usa NEW, DELETE usa OLD)
  v_evento_id := COALESCE(NEW.id_evento, OLD.id_evento);

  SELECT COALESCE(SUM(n_persone), 0)
  INTO v_count
  FROM public.prenotazioni
  WHERE id_evento = v_evento_id
    AND stato = 'confermata';

  UPDATE public.eventi
  SET posti_prenotati = v_count,
      updated_at      = now()
  WHERE id = v_evento_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_update_posti_prenotati ON public.prenotazioni;
CREATE TRIGGER trg_update_posti_prenotati
  AFTER INSERT OR UPDATE OR DELETE ON public.prenotazioni
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_posti_prenotati();


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 6 — TRIGGER: Decremento stock prevendite (race-condition fix)║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION public.fn_decrement_prevendita_stock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_remaining integer;
BEGIN
  -- Decremento atomico con lock implicito su UPDATE
  UPDATE public.prevendite
  SET quantita_disponibile = quantita_disponibile - 1
  WHERE id_prevendita = NEW.id_prevendita
    AND quantita_disponibile > 0
  RETURNING quantita_disponibile INTO v_remaining;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prevendita esaurita (id=%)', NEW.id_prevendita
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_decrement_prevendita_stock ON public.prenotazioni_prevendite;
CREATE TRIGGER trg_decrement_prevendita_stock
  BEFORE INSERT ON public.prenotazioni_prevendite
  FOR EACH ROW EXECUTE FUNCTION public.fn_decrement_prevendita_stock();


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 7 — FUNCTION register_user_transaction CORRETTA (R10)        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Rinomina i riferimenti: users→utenti, users_phones→utenti_numeri_telefono,
-- countries→paesi, iso→iso_code, code→iso_code, dial_code→numero_prefisso

-- DROP necessario: PostgreSQL non permette di rinominare parametri con OR REPLACE
DROP FUNCTION IF EXISTS public.register_user_transaction(uuid,text,text,text,date,text,text);

CREATE OR REPLACE FUNCTION public.register_user_transaction(
  p_id_utente    uuid,
  p_nome         text,
  p_cognome      text,
  p_email        text,
  p_data_nascita date,
  p_telefono     text,
  p_country_iso  text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_adult   boolean := false;
  v_country_id uuid    := null;
  v_now        timestamptz := now();
  v_dial       text    := null;
  v_e164       text    := null;
BEGIN
  -- ── Validazione ──
  IF p_nome IS NULL OR length(trim(p_nome)) = 0 THEN
    RAISE EXCEPTION 'Nome obbligatorio';
  END IF;
  IF p_cognome IS NULL OR length(trim(p_cognome)) = 0 THEN
    RAISE EXCEPTION 'Cognome obbligatorio';
  END IF;
  IF p_data_nascita IS NULL THEN
    RAISE EXCEPTION 'Data di nascita obbligatoria';
  END IF;
  IF p_telefono IS NULL OR length(trim(p_telefono)) < 7 THEN
    RAISE EXCEPTION 'Telefono non valido';
  END IF;

  -- ── Calcolo maggiore età ──
  v_is_adult := (date_part('year', age(current_date, p_data_nascita)) >= 18);

  -- ── Lookup paese (tabella corretta: paesi, colonna: iso_code) ──
  SELECT id, numero_prefisso
  INTO v_country_id, v_dial
  FROM public.paesi
  WHERE upper(iso_code) = upper(p_country_iso)
  LIMIT 1;

  -- ── Sanitizzazione E.164 ──
  v_e164 := replace(coalesce(p_telefono, ''), ' ', '');
  IF v_e164 IS NULL OR v_e164 = '' THEN
    RAISE EXCEPTION 'Telefono non valido';
  END IF;
  IF v_e164 !~ '^\+' THEN
    v_e164 := '+' || v_e164;
  END IF;

  -- ── Upsert utente (tabella corretta: utenti) ──
  INSERT INTO public.utenti (id, nome, cognome, email, data_nascita, maggiorenne, created_at)
  VALUES (p_id_utente, p_nome, p_cognome, p_email, p_data_nascita, v_is_adult, v_now)
  ON CONFLICT (id) DO UPDATE
    SET nome         = EXCLUDED.nome,
        cognome      = EXCLUDED.cognome,
        email        = EXCLUDED.email,
        data_nascita = EXCLUDED.data_nascita,
        maggiorenne  = EXCLUDED.maggiorenne,
        updated_at   = v_now;

  -- ── Upsert telefono (tabella corretta: utenti_numeri_telefono) ──
  INSERT INTO public.utenti_numeri_telefono
    (id_utente, country_id, telefono, is_primary, is_verified, created_at)
  VALUES
    (p_id_utente, v_country_id, v_e164, true, false, v_now)
  ON CONFLICT (id_utente, telefono) DO UPDATE
    SET country_id  = EXCLUDED.country_id,
        is_primary  = EXCLUDED.is_primary,
        is_verified = EXCLUDED.is_verified,
        updated_at  = v_now;

  RETURN json_build_object(
    'user_id',     p_id_utente,
    'country_id',  v_country_id,
    'maggiorenne', v_is_adult,
    'status',      'ok'
  );
END;
$$;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 8 — UNIQUE CONSTRAINT per upsert telefono                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- La function sopra fa ON CONFLICT (id_utente, telefono), serve un indice unico
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'utenti_numeri_telefono'
      AND indexdef ILIKE '%id_utente%telefono%'
  ) THEN
    CREATE UNIQUE INDEX idx_uq_utente_telefono
      ON public.utenti_numeri_telefono (id_utente, telefono);
  END IF;
END $$;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 9 — PULIZIA RLS POLICIES DUPLICATE                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ── utenti: teniamo "Gli utenti gestiscono proprio profilo" (ALL), rimuoviamo le singole ──
DROP POLICY IF EXISTS "users_insert_own"  ON public.utenti;
DROP POLICY IF EXISTS "users_select_own"  ON public.utenti;
DROP POLICY IF EXISTS "users_update_own"  ON public.utenti;

-- ── utenti_numeri_telefono: teniamo "Gestione del proprio telefono" (ALL), rimuoviamo le singole ──
DROP POLICY IF EXISTS "phones_insert_own" ON public.utenti_numeri_telefono;
DROP POLICY IF EXISTS "phones_select_own" ON public.utenti_numeri_telefono;
DROP POLICY IF EXISTS "phones_update_own" ON public.utenti_numeri_telefono;

-- ── preferiti: teniamo "Utente gestisce suoi preferiti" (ALL) ──
DROP POLICY IF EXISTS "preferiti_own" ON public.preferiti;

-- ── prenotazioni: rimuoviamo set vecchio ──
DROP POLICY IF EXISTS "Utente legge proprie prenotazioni"              ON public.prenotazioni;
DROP POLICY IF EXISTS "Utenti inseriscono prenotazioni"                ON public.prenotazioni;
DROP POLICY IF EXISTS "Utenti leggono le proprie prenotazioni"         ON public.prenotazioni;

-- ── prenotazioni_tavolo: rimuoviamo set vecchio ──
DROP POLICY IF EXISTS "Utenti inseriscono prenotazioni tavolo"         ON public.prenotazioni_tavolo;
DROP POLICY IF EXISTS "Utenti leggono le proprie prenotazioni_tavolo"  ON public.prenotazioni_tavolo;

-- ── ordini: rimuoviamo duplicato ──
DROP POLICY IF EXISTS "Utenti: select propri ordini"                   ON public.ordini;

-- ── locali: rimuoviamo duplicato ──
DROP POLICY IF EXISTS "locali_read_public" ON public.locali;

-- ── eventi: rimuoviamo duplicati ──
DROP POLICY IF EXISTS "public_select_eventi"  ON public.eventi;
DROP POLICY IF EXISTS "eventi_read_public"    ON public.eventi;

-- ── citta: rimuoviamo duplicato ──
DROP POLICY IF EXISTS "citta_read_public" ON public.citta;

-- ── paesi: rimuoviamo duplicato ──
DROP POLICY IF EXISTS "countries_select_all" ON public.paesi;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 10 — POLICIES MANCANTI                                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Abilita RLS se non attivo
ALTER TABLE public.prevendite       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cap              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posti_famosi     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provincia        ENABLE ROW LEVEL SECURITY;

-- Prevendite: chiunque autenticato può leggere
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'prevendite' AND policyname = 'Tutti leggono prevendite'
  ) THEN
    CREATE POLICY "Tutti leggono prevendite"
      ON public.prevendite FOR SELECT
      USING (true);
  END IF;
END $$;

-- Ordini: l'utente può inserire i propri ordini
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'ordini' AND policyname = 'Utente inserisce propri ordini'
  ) THEN
    CREATE POLICY "Utente inserisce propri ordini"
      ON public.ordini FOR INSERT
      WITH CHECK (auth.uid() = utente_id);
  END IF;
END $$;

-- Ordini: l'utente può aggiornare i propri ordini
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'ordini' AND policyname = 'Utente aggiorna propri ordini'
  ) THEN
    CREATE POLICY "Utente aggiorna propri ordini"
      ON public.ordini FOR UPDATE
      USING (auth.uid() = utente_id)
      WITH CHECK (auth.uid() = utente_id);
  END IF;
END $$;

-- CAP: lettura pubblica
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'cap' AND policyname = 'Tutti leggono cap'
  ) THEN
    CREATE POLICY "Tutti leggono cap"
      ON public.cap FOR SELECT
      USING (true);
  END IF;
END $$;

-- Posti famosi: lettura pubblica
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'posti_famosi' AND policyname = 'Tutti leggono posti famosi'
  ) THEN
    CREATE POLICY "Tutti leggono posti famosi"
      ON public.posti_famosi FOR SELECT
      USING (true);
  END IF;
END $$;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 11 — INDICI DI PERFORMANCE                                   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Prenotazioni per evento (usato dal trigger posti_prenotati)
CREATE INDEX IF NOT EXISTS idx_prenotazioni_evento_stato
  ON public.prenotazioni (id_evento, stato);

-- Prenotazioni per utente (usato da RLS e OrdersService)
CREATE INDEX IF NOT EXISTS idx_prenotazioni_utente
  ON public.prenotazioni (id_utente);

-- Prenotazioni_prevendite per prenotazione (JOIN frequente)
CREATE INDEX IF NOT EXISTS idx_prenot_prev_prenotazione
  ON public.prenotazioni_prevendite (id_prenotazione);

-- Prenotazioni_prevendite per utente (RLS)
CREATE INDEX IF NOT EXISTS idx_prenot_prev_utente
  ON public.prenotazioni_prevendite (id_utente);

-- Prenotazioni_tavolo per utente (RLS + OrdersService)
CREATE INDEX IF NOT EXISTS idx_prenot_tavolo_utente
  ON public.prenotazioni_tavolo (id_utente);

-- Prenotazioni_tavolo per evento (BookingService.getTavoli)
CREATE INDEX IF NOT EXISTS idx_prenot_tavolo_evento
  ON public.prenotazioni_tavolo (id_evento);

-- Eventi per club + stato (ClubService.getUpcomingEventi)
CREATE INDEX IF NOT EXISTS idx_eventi_club_stato
  ON public.eventi (club_id, stato, inizio_evento);

-- Locali per città (ClubService JOINs)
CREATE INDEX IF NOT EXISTS idx_locali_citta
  ON public.locali (id_citta);

-- Preferiti per utente (ClubService.isPreferito)
CREATE INDEX IF NOT EXISTS idx_preferiti_utente
  ON public.preferiti (id_utente, locale_id);

-- Notifiche per utente + letto (NotificationService)
CREATE INDEX IF NOT EXISTS idx_notifiche_utente_letto
  ON public.notifiche (utente_id, letto, created_at DESC);

-- Analytics per event_name (Looker Studio queries)
CREATE INDEX IF NOT EXISTS idx_analytics_event_name
  ON public.analytics_events (event_name, created_at DESC);

-- Gestori per club (my_club_id function)
CREATE INDEX IF NOT EXISTS idx_gestori_club_attivo
  ON public.gestori (club_id, attivo);

-- Prevendite per evento (BookingService.getPrevendite)
CREATE INDEX IF NOT EXISTS idx_prevendite_evento
  ON public.prevendite (id_evento);

-- Nota: l'indice trigram richiede l'estensione pg_trgm
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Città ricerca ILIKE (LocationService.searchCitta)
CREATE INDEX IF NOT EXISTS idx_citta_nome_trgm
  ON public.citta USING gin (nome_citta gin_trgm_ops);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 12 — VIEW: maggiorenne calcolato (alternativa a R1)          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- View che calcola maggiorenne al volo, senza dipendere dal campo statico
CREATE OR REPLACE VIEW public.v_utenti_profilo AS
SELECT
  u.id,
  u.email,
  u.nome,
  u.cognome,
  u.data_nascita,
  (date_part('year', age(current_date, u.data_nascita)) >= 18) AS maggiorenne,
  u.raggio_km,
  u.created_at,
  u.updated_at,
  p.telefono,
  p.is_verified,
  pa.iso_code  AS country_iso,
  pa.nome      AS country_nome
FROM public.utenti u
LEFT JOIN public.utenti_numeri_telefono p
  ON p.id_utente = u.id AND p.is_primary = true
LEFT JOIN public.paesi pa
  ON pa.id = p.country_id;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SEZIONE 13 — VIEW: dashboard eventi per gestori                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

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
  -- Conteggi reali (non dal campo cached)
  (SELECT count(*)
   FROM public.prenotazioni pr
   WHERE pr.id_evento = e.id AND pr.stato = 'confermata'
  ) AS prenotazioni_confermate,
  (SELECT COALESCE(sum(pr.prezzo_totale), 0)
   FROM public.prenotazioni pr
   WHERE pr.id_evento = e.id AND pr.stato = 'confermata'
  ) AS incasso_reale,
  -- Prevendite vendute
  (SELECT count(*)
   FROM public.prenotazioni_prevendite pp
   JOIN public.prevendite pv ON pv.id_prevendita = pp.id_prevendita
   WHERE pv.id_evento = e.id
  ) AS biglietti_venduti,
  -- Tavoli prenotati
  (SELECT count(*)
   FROM public.prenotazioni_tavolo pt
   WHERE pt.id_evento = e.id AND pt.stato != 'annullata'
  ) AS tavoli_prenotati
FROM public.eventi e
JOIN public.locali l ON l.id = e.club_id
LEFT JOIN public.citta c ON c.id_citta = l.id_citta
ORDER BY e.inizio_evento DESC;


COMMIT;

-- ============================================================================
-- FINE MIGRAZIONE
-- ============================================================================
