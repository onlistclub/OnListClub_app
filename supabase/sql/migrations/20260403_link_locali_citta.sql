-- ============================================================
-- Migration: collega locali alla tabella citta tramite id_citta
-- Data: 2026-04-03
-- ============================================================
--
-- Problema: molti locali hanno il campo testo `citta` valorizzato
-- ma `id_citta` (FK) a NULL. Il JOIN usato dalla app non restituisce
-- nulla → i locali non hanno coordinate città → escludono dal filtro
-- raggio e mostrano nomeCitta NULL.
--
-- Fix:
--   1. Inserisce le città Valle d'Aosta mancanti in `citta`
--   2. Aggiorna `locali.id_citta` facendo match sul nome città
-- ============================================================

-- ── 1. Inserisci città mancanti ──────────────────────────────────────────────

INSERT INTO citta (nome_citta, lat, lng)
SELECT v.nome, v.lat, v.lng
FROM (VALUES
  ('Aosta',           45.7376,  7.3210),
  ('Courmayeur',      45.7929,  6.9691),
  ('Breuil-Cervinia', 45.9375,  7.6266),
  ('La Thuile',       45.7256,  6.9722),
  ('Cogne',           45.6075,  7.3579)
) AS v(nome, lat, lng)
WHERE NOT EXISTS (
  SELECT 1 FROM citta WHERE lower(nome_citta) = lower(v.nome)
);

-- ── 2. Collega i locali alla citta corrispondente ────────────────────────────
-- Match case-insensitive tra locali.citta (testo) e citta.nome_citta

UPDATE locali l
SET id_citta = c.id_citta
FROM citta c
WHERE lower(trim(l.citta)) = lower(trim(c.nome_citta))
  AND l.id_citta IS NULL
  AND l.citta IS NOT NULL;
