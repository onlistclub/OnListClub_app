-- =============================================================================
--  SEED TEST — una serata OGGI e una DOMANI per OGNI club (partenza 23:00)
--  Scopo: popolare le card "Prossime serate" per testare il rendering
--         OGGI/DOMANI (card grande) vs altre date (card compatta).
--  Come:  eseguire l'intero file dal SQL Editor di Supabase Studio.
--         Idempotente: NON crea doppioni se un club ha già una serata attiva
--         in quella data. Rilanciabile senza danni.
--
--  Note tecniche:
--   - Gli orari sono salvati in fuso Europe/Rome: 23:00 Rome -> 21:00 UTC in
--     estate (CEST). L'app fa inizio_evento.toLocal(), quindi su un device in
--     Italia mostra "23:00" e la data giusta (OGGI/DOMANI).
--   - Fine serata: 04:00 del giorno dopo (Rome).
--   - descrizione = 'seed_test_oggi_domani' -> marker per la pulizia.
--
--  PULIZIA (rimuove SOLO queste serate di test):
--     DELETE FROM public.eventi WHERE descrizione = 'seed_test_oggi_domani';
-- =============================================================================

WITH rome AS (SELECT (now() AT TIME ZONE 'Europe/Rome')::date AS today),
clubs AS (
  SELECT l.id, row_number() OVER (ORDER BY l.nome) - 1 AS rn FROM public.locali l
),
tpl AS (SELECT * FROM (VALUES (0),(1)) AS t(day_offset)),  -- 0 = stasera, 1 = domani
variants AS (
  SELECT * FROM (VALUES
    (0, 'Commercial Hits',    ARRAY['Commercial','Pop','Dance']),
    (1, 'Reggaeton Night',    ARRAY['Reggaeton','Latin']),
    (2, 'Techno Underground', ARRAY['Techno','Tech House']),
    (3, 'House Party',        ARRAY['House','Afro House']),
    (4, 'Latin Fever',        ARRAY['Latin','Reggaeton']),
    (5, 'Hip-Hop Session',    ARRAY['Hip-Hop','Trap']),
    (6, 'Deep & Melodic',     ARRAY['Deep House','Melodic']),
    (7, 'Mainstage Anthems',  ARRAY['EDM','Electro'])
  ) AS v(idx, nome, generi)
)
INSERT INTO public.eventi
  (club_id, nome, inizio_evento, fine_evento, stato, generi_musicali,
   dress_code, eta_minima, sound_system, parcheggio, lineup, descrizione, ingressi_previsti)
SELECT
  c.id,
  v.nome,
  (((r.today + t.day_offset)     + time '23:00') AT TIME ZONE 'Europe/Rome'),
  (((r.today + t.day_offset + 1) + time '04:00') AT TIME ZONE 'Europe/Rome'),
  'attivo',
  v.generi,
  'Smart casual',
  '18+',
  'Funktion-One',
  'Disponibile in zona',
  jsonb_build_array(
    jsonb_build_object('nome','DJ Resident','iniziali','DR','stage','Main Stage','ora_inizio','23:00','ora_fine','04:00','headliner',true),
    jsonb_build_object('nome','Guest DJ','iniziali','GD','stage','Second Room','ora_inizio','00:00','ora_fine','04:00','headliner',false)
  ),
  'seed_test_oggi_domani',
  0
FROM clubs c
CROSS JOIN tpl t
CROSS JOIN rome r
JOIN variants v ON v.idx = ((c.rn + t.day_offset) % 8)
WHERE NOT EXISTS (
  SELECT 1 FROM public.eventi e
  WHERE e.club_id = c.id
    AND (e.inizio_evento AT TIME ZONE 'Europe/Rome')::date = (r.today + t.day_offset)
    AND e.stato = 'attivo'
);
