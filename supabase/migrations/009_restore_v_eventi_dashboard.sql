-- =============================================================================
-- OnList Club — Ripristino view v_eventi_dashboard (009)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
--
-- Problema: la view public.v_eventi_dashboard non esiste più nel database.
-- PostgREST risponde PGRST205 ("Could not find the table
-- 'public.v_eventi_dashboard' in the schema cache") a ogni SELECT.
-- Conseguenze sul gestionale web (Sito_Web_OnListClub_MVP):
--   - /storico  → getStoricoData fa throw → pagina di errore;
--   - /dashboard → l'errore veniva ignorato, i KPI mostravano tutti 0.
-- Le view sorelle (v_prenotazioni_dashboard, v_utenti_profilo) sono invece
-- presenti: è caduta solo questa.
--
-- Soluzione: ricrea la view con la definizione canonica di
-- 001_struttura_iniziale.sql, che è identica a quella di
-- sql/migrations/20260504_analisi_fix.sql, e ripristina security_invoker = true
-- come impostato da docs/database/migrations/2026-05-30_phaseA_critici.sql (A3).
-- =============================================================================

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

-- Ogni accesso rispetta la RLS delle tabelle sottostanti (vedi A3 di
-- 2026-05-30_phaseA_critici.sql): senza questo la view tornerebbe
-- SECURITY DEFINER e leakerebbe le metriche di tutti i locali.
ALTER VIEW public.v_eventi_dashboard SET (security_invoker = true);

-- =============================================================================
-- Verifiche post-applicazione
-- =============================================================================
-- 1) La view esiste ed è security_invoker:
--    SELECT relname, reloptions FROM pg_class
--    WHERE relkind='v' AND relname='v_eventi_dashboard';
--    -> reloptions deve contenere {security_invoker=true}
--
-- 2) PostgREST la espone di nuovo (schema cache ricaricata):
--    NOTIFY pgrst, 'reload schema';
--    poi da terminale: curl "$SUPABASE_URL/rest/v1/v_eventi_dashboard?select=evento_id&limit=1"
--    -> 200, non più PGRST205
