-- =============================================================================
-- OnList Club — Le tabelle del foglio di monitoraggio si chiudono a chiave (015)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
-- DOPO la 014 (che sistema le policy di scrittura su analytics_events).
--
-- COSA PROTEGGE
-- Il foglio "Dati" legge due tabelle, ed entrambe contengono materiale che non
-- deve uscire con la chiave pubblica:
--
--   analytics_events  → user_id, platform, device_model, os_version, e i
--                       metadata degli errori. Un profilo di uso per persona.
--   activity_events   → session_id, user_id, club_id, path, referrer,
--                       user_agent. La cronologia di navigazione dei visitatori
--                       del sito, compresi quelli mai registrati.
--
-- Nessuno dei due client ha motivo di leggerle: l'app scrive e basta
-- (analytics_service.dart), il sito scrive server-side con la service_role
-- (activity.functions.ts → supabaseAdmin), e il foglio interroga anche lui con
-- la service_role. Quindi qui togliamo tutto a `anon` e `authenticated` invece
-- di fidarci del fatto che "tanto non c'è una policy di SELECT".
--
-- PERCHÉ NON BASTA "non c'è la policy"
-- Con la RLS attiva e nessuna policy di SELECT, una lettura torna vuota: sembra
-- protetto. Ma è una protezione che regge su un'assenza — la prima policy
-- scritta di fretta con `USING (true)`, o un `ENABLE ROW LEVEL SECURITY`
-- dimenticato su una tabella nuova, e i dati escono. Il GRANT revocato è una
-- seconda serratura, indipendente dalla prima.
--
-- ⚠️  `activity_events` è stata creata a mano dal file
--     Sito_Web_OnListClub_MVP/supabase/migrations/20260710120000_activity_events.sql,
--     che non è mai passato da una CLI. Se questa migration fallisce con
--     "relation does not exist", la risposta non è creare la tabella qui: è che
--     quel file non è mai stato eseguito, e allora il tracciamento del sito non
--     ha mai scritto niente. Verificalo prima di proseguire.
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. activity_events — il tracciamento del sito
--
-- Scritta solo da `logActivityEvents` con la service_role, che passa sopra la
-- RLS: togliere ogni privilegio ai ruoli pubblici non tocca il tracker.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.activity_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.activity_events FROM anon, authenticated;
GRANT ALL ON public.activity_events TO service_role;

COMMENT ON TABLE public.activity_events IS
  'Navigazione del sito (page_view, click, download_click). Scrittura solo via service_role dalla server function logActivityEvents; lettura solo service_role (foglio "Dati"). Nessun privilegio ad anon/authenticated.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. analytics_events — gli eventi dell'app
--
-- La 014 ha già assegnato INSERT ad anon/authenticated e revocato il resto.
-- Qui si ribadisce solo la lettura, perché è la riga che conta e perché questa
-- migration deve poter essere letta da sola fra sei mesi.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

REVOKE SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.analytics_events FROM anon, authenticated;
GRANT ALL ON public.analytics_events TO service_role;

COMMENT ON TABLE public.analytics_events IS
  'Eventi dell''app (funnel, tempi di caricamento, errori, dispositivi). Solo INSERT da anon/authenticated con i vincoli della 014; lettura riservata alla service_role del foglio "Dati".';

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Verifiche post-applicazione
-- =============================================================================
-- 1) Con la sola chiave pubblica non si legge più niente:
--    curl "$SUPABASE_URL/rest/v1/activity_events?select=*&limit=1"  -H "apikey: <publishable>"
--    curl "$SUPABASE_URL/rest/v1/analytics_events?select=*&limit=1" -H "apikey: <publishable>"
--    -> permission denied su entrambe. Ripeti con un JWT di utente vero: idem.
--
-- 2) La scrittura dall'app funziona ancora (è il rischio di questa migration):
--    apri l'app e controlla che arrivino righe nuove,
--    SELECT count(*) FROM public.analytics_events WHERE created_at > now() - interval '5 minutes';
--
-- 3) Il tracciamento del sito funziona ancora: naviga due pagine, poi
--    SELECT count(*) FROM public.activity_events WHERE created_at > now() - interval '5 minutes';
--
-- =============================================================================
-- Il resto della fotografia RLS — queste due query valgono il giorno 4
-- =============================================================================
-- A) Tabelle con la RLS SPENTA (ognuna è leggibile da chiunque abbia un GRANT):
--    SELECT relname
--    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
--    WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
--    ORDER BY relname;
--    -- L'ultima istantanea in docs/database/struttura_rls.json dava spente
--    -- `pagamenti` e `biglietti`, ed è un file vecchio e incompleto: fidati di
--    -- questa query, non di quel JSON.
--
-- B) Chi può LEGGERE cosa con la chiave pubblica:
--    SELECT table_name, grantee, privilege_type
--    FROM information_schema.role_table_grants
--    WHERE table_schema = 'public'
--      AND grantee IN ('anon', 'authenticated')
--      AND privilege_type = 'SELECT'
--    ORDER BY table_name, grantee;
--    -- Ogni riga qui è una tabella che un utente dell'app può interrogare:
--    -- se non ha una policy che la restringe, la legge tutta.
--
-- =============================================================================
-- Quello che questa migration NON protegge, ed è il punto più esposto
-- =============================================================================
-- Il foglio "Dati" interroga Supabase con la SERVICE_ROLE KEY, scritta dentro
-- l'Apps Script allegato al foglio. Quella chiave scavalca ogni RLS e ogni
-- GRANT: chi la legge ha il database intero, non solo le due tabelle di qui.
-- E la legge chiunque abbia accesso in modifica al foglio, perché lo script si
-- apre da Estensioni → Apps Script.
--
-- Quindi, prima del lancio:
--   - controlla CON CHI è condiviso il foglio, e togli i permessi di modifica
--     a chi non deve avere il database (la sola visualizzazione non basta a
--     leggere lo script, la modifica sì);
--   - non duplicare il foglio e non condividerlo "con il link";
--   - metti la chiave nelle Script Properties invece che nel codice — non è
--     una vera barriera, ma evita che compaia in una copia o in uno screenshot;
--   - se è già girata a qualcuno che non deve averla, ruotala dal pannello
--     Supabase e aggiorna lo script.
-- Nessuna riga SQL può fare questo lavoro al posto tuo.
