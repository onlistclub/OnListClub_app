-- =============================================================================
-- OnList Club — Sessioni negli eventi dell'app (016)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
-- (SQL editor, a mano, come la 014 e la 015).
--
-- IL PROBLEMA
-- `analytics_events` non aveva niente che legasse tra loro gli eventi di una
-- stessa visita. Prima del login `user_id` è NULL, quindi il percorso
-- app_open → registrazione → home → prenotazione di una persona non era
-- ricostruibile: si potevano solo contare gli eventi.
--
-- LA CORREZIONE
-- Da questa versione l'app mette in `metadata` di OGNI evento:
--   session_id → uguale per tutta la visita, anche a cavallo del login
--   seq        → ordine degli eventi dentro l'avvio dell'app
--   client_ts  → ora del telefono
-- (vedi lib/core/services/analytics_service.dart).
--
-- Qui `session_id` diventa una colonna vera, calcolata dal metadata, così la
-- dashboard può raggruppare e filtrare per sessione con un indice.
--
-- ORDINE DI RILASCIO: indifferente. L'app scrive il valore dentro `metadata`,
-- non nella colonna: una build nuova funziona anche prima di questa migration,
-- e la colonna si riempie da sola anche per gli eventi già arrivati.
-- Gli eventi delle versioni precedenti restano con session_id NULL.
--
-- PER ORDINARE IL PERCORSO usare (session_id, metadata->>'seq'), non
-- created_at: gli insert partono in parallelo e il DB li data all'arrivo.
-- =============================================================================

BEGIN;

ALTER TABLE public.analytics_events
  ADD COLUMN IF NOT EXISTS session_id text
  GENERATED ALWAYS AS (metadata->>'session_id') STORED;

CREATE INDEX IF NOT EXISTS idx_analytics_session
  ON public.analytics_events USING btree (session_id, created_at);

COMMENT ON COLUMN public.analytics_events.session_id IS
  'Visita dell''app (da metadata.session_id). NULL per gli eventi delle versioni precedenti alla 016. Ordine interno: (metadata->>''seq'')::int.';

COMMIT;

NOTIFY pgrst, 'reload schema';

-- -----------------------------------------------------------------------------
-- VERIFICA (dopo aver aperto una build nuova dell'app)
--
--   SELECT session_id, event_name, (metadata->>'seq')::int AS seq, created_at
--   FROM public.analytics_events
--   WHERE created_at > now() - interval '15 minutes'
--   ORDER BY session_id, seq;
--
-- Atteso: session_start, screen_splash, app_open… con lo stesso session_id.
-- -----------------------------------------------------------------------------
