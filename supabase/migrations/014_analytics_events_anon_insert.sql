-- =============================================================================
-- OnList Club — La cima del funnel arriva anche dagli utenti non loggati (014)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
--
-- IL PROBLEMA
-- L'unica policy su `analytics_events` è "Allow authenticated inserts", con
-- WITH CHECK (auth.role() = 'authenticated'). Ma l'app manda eventi molto prima
-- che qualcuno abbia un account:
--
--   app_open        → main.dart, al primo frame
--   gps_permission  → schermata permessi posizione
--   screen_*        → splash, login, registrazione (mixin ScreenAnalytics)
--   error/http_error→ handler globali, che non aspettano il login
--
-- Tutti scartati in silenzio (AnalyticsService.log ingoia l'eccezione per non
-- bloccare mai l'app). Il risultato nel foglio è un funnel che parte dal
-- secondo gradino: le "Aperture" contano solo chi era già loggato, quindi il
-- rapporto aperture → registrazioni → prenotazioni non è calcolabile. Ed è
-- esattamente la domanda a cui l'MVP deve rispondere.
--
-- LA CORREZIONE
-- Una policy di INSERT per `anon`, con due paletti che la vecchia policy non
-- aveva:
--   - `user_id IS NULL`: chi non è autenticato non può attribuire un evento a
--     un account altrui. La chiave publishable sta dentro l'app, quindi la
--     conosce chiunque: senza questo vincolo si potrebbero fabbricare eventi a
--     nome di un utente qualsiasi.
--   - nessun SELECT: anon scrive e basta. La tabella resta illeggibile senza
--     service_role (è così che la interroga il foglio).
--
-- La parte 2 stringe la stessa vite sulla policy degli autenticati, che oggi
-- accetta qualunque user_id da qualunque utente loggato. L'app scrive sempre
-- `user_id = currentUser?.id`, quindi il vincolo non cambia niente per lei.
-- =============================================================================

BEGIN;

-- Senza RLS attiva le policy non si applicano e la tabella sarebbe scrivibile
-- da chiunque senza vincoli. Idempotente.
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Visitatore non autenticato: può scrivere solo eventi senza utente
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS analytics_events_insert_anon ON public.analytics_events;
CREATE POLICY analytics_events_insert_anon ON public.analytics_events
  FOR INSERT
  TO anon
  WITH CHECK (user_id IS NULL);

COMMENT ON POLICY analytics_events_insert_anon ON public.analytics_events IS
  'Eventi prima del login (app_open, gps_permission, screen_* di registrazione). Solo eventi anonimi: user_id deve essere NULL.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Utente autenticato: può scrivere solo a nome proprio
--
-- La vecchia "Allow authenticated inserts" controllava solo che il ruolo fosse
-- `authenticated`, senza legare `user_id` a chi stava scrivendo: un utente
-- qualsiasi poteva inserire eventi attribuiti a un altro account. Il NULL
-- resta ammesso perché l'app scrive `user_id: currentUser?.id`, che è NULL nel
-- breve tratto fra avvio e ripristino della sessione.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Allow authenticated inserts" ON public.analytics_events;
DROP POLICY IF EXISTS analytics_events_insert_authenticated ON public.analytics_events;
CREATE POLICY analytics_events_insert_authenticated ON public.analytics_events
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

COMMENT ON POLICY analytics_events_insert_authenticated ON public.analytics_events IS
  'Sostituisce "Allow authenticated inserts": stesso permesso di scrittura, ma l''evento non può essere attribuito a un altro utente.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. I privilegi di tabella
--
-- La RLS filtra le righe, ma PostgREST passa solo se il ruolo ha anche il
-- GRANT. Scrittura sì, lettura no: nessuno deve poter rileggere gli eventi
-- degli altri, il foglio di monitoraggio interroga con la service_role.
-- ─────────────────────────────────────────────────────────────────────────────
GRANT INSERT ON public.analytics_events TO anon, authenticated;
REVOKE SELECT, UPDATE, DELETE ON public.analytics_events FROM anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Verifiche post-applicazione
-- =============================================================================
-- 1) Prima/dopo, sul campo: disinstalla e riapri l'app SENZA fare login, poi
--    SELECT event_name, user_id, platform, created_at
--    FROM public.analytics_events
--    WHERE created_at > now() - interval '10 minutes'
--    ORDER BY created_at;
--    -> devono comparire app_open e gli screen_* di login/registrazione, con
--       user_id NULL. Prima di questa migration quella lista era vuota.
--
-- 2) Un utente loggato non può firmare eventi altrui: con il JWT di A,
--    curl -X POST "$SUPABASE_URL/rest/v1/analytics_events" \
--      -H "apikey: <publishable>" -H "Authorization: Bearer <jwt di A>" \
--      -H "Content-Type: application/json" \
--      -d '{"event_name":"prova","user_id":"<id di B>"}'
--    -> 403 (new row violates row-level security policy).
--
-- 3) Nessuno può rileggere la tabella con la chiave pubblica:
--    curl "$SUPABASE_URL/rest/v1/analytics_events?select=*&limit=1" \
--      -H "apikey: <publishable>"
--    -> permission denied / lista vuota, mai i dati.
--
-- =============================================================================
-- Quello che questa migration NON può fare
-- =============================================================================
-- La chiave publishable è dentro l'app, quindi estraibile: chiunque può
-- infilare righe finte in `analytics_events`. È il prezzo di qualsiasi
-- analytics lato client e non si chiude con la RLS — servirebbe far passare
-- gli eventi da una Edge Function con rate limit.
-- Per un MVP che misura tendenze va bene così; tienilo a mente il giorno in cui
-- questi numeri dovessero diventare la base di un contratto o di un rendiconto.
--
-- Nota per il foglio: adesso arrivano righe con user_id NULL. Le query che
-- contano UTENTI (non eventi) devono continuare a filtrare user_id NOT NULL,
-- altrimenti gli anonimi finiscono tutti in un unico "utente" fantasma. La TAB
-- Dispositivi, che prende l'ultimo evento per user_id, non è toccata.
