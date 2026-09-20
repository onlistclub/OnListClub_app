-- ============================================================
-- Migration: aggiunge alla tabella `eventi` i campi mostrati
-- nella schermata 19 (pop-up info serata, Figma `off/19`).
-- Data: 2026-05-31
-- Idempotente: usa IF NOT EXISTS.
-- ============================================================

ALTER TABLE eventi ADD COLUMN IF NOT EXISTS dress_code   text;
ALTER TABLE eventi ADD COLUMN IF NOT EXISTS eta_minima   text;
ALTER TABLE eventi ADD COLUMN IF NOT EXISTS sound_system text;
ALTER TABLE eventi ADD COLUMN IF NOT EXISTS parcheggio   text;

-- Line-up DJ come array JSON. Ogni elemento ha shape:
--   { "nome": "Derrik", "iniziali": "DK", "stage": "Main Stage",
--     "ora_inizio": "23:00", "ora_fine": "03:00", "headliner": true }
ALTER TABLE eventi ADD COLUMN IF NOT EXISTS lineup       jsonb;

COMMENT ON COLUMN eventi.dress_code   IS 'Dress code dell''evento (es. "Total Black").';
COMMENT ON COLUMN eventi.eta_minima   IS 'Età minima e note (es. "16+ Documento obbligatorio").';
COMMENT ON COLUMN eventi.sound_system IS 'Impianto audio (es. "Funktion 50kw").';
COMMENT ON COLUMN eventi.parcheggio   IS 'Parcheggio (es. "Gratuito", "A pagamento").';
COMMENT ON COLUMN eventi.lineup       IS 'Array JSON di DJ: {nome, iniziali, stage, ora_inizio, ora_fine, headliner}.';
