-- ============================================================
-- Migration: crea tabella prenotazioni_tavolo
-- Data: 2026-04-02
-- ============================================================

CREATE TABLE IF NOT EXISTS prenotazioni_tavolo (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     UUID        NOT NULL REFERENCES locali(id)  ON DELETE CASCADE,
  utente_id   UUID        NOT NULL REFERENCES utenti(id)  ON DELETE CASCADE,
  num_persone INTEGER     NOT NULL DEFAULT 1 CHECK (num_persone > 0),
  orario      TIMESTAMPTZ,
  note        TEXT,
  stato       TEXT        NOT NULL DEFAULT 'in_attesa'
                            CHECK (stato IN ('in_attesa', 'confermata', 'annullata')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indici per le query più frequenti
CREATE INDEX IF NOT EXISTS prenotazioni_tavolo_club_id_idx    ON prenotazioni_tavolo(club_id);
CREATE INDEX IF NOT EXISTS prenotazioni_tavolo_utente_id_idx  ON prenotazioni_tavolo(utente_id);
CREATE INDEX IF NOT EXISTS prenotazioni_tavolo_stato_idx      ON prenotazioni_tavolo(stato);
