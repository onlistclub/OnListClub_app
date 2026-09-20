-- ============================================================
-- Migration: crea tabella biglietti
-- Data: 2026-04-01
-- ============================================================

CREATE TABLE IF NOT EXISTS biglietti (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  evento_id  UUID        NOT NULL REFERENCES eventi(id)  ON DELETE CASCADE,
  utente_id  UUID        NOT NULL REFERENCES utenti(id)  ON DELETE CASCADE,
  quantita   INTEGER     NOT NULL DEFAULT 1 CHECK (quantita > 0),
  stato      TEXT        NOT NULL DEFAULT 'attivo'
                           CHECK (stato IN ('attivo', 'usato', 'annullato')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indici per le query più frequenti
CREATE INDEX IF NOT EXISTS biglietti_evento_id_idx  ON biglietti(evento_id);
CREATE INDEX IF NOT EXISTS biglietti_utente_id_idx  ON biglietti(utente_id);
CREATE INDEX IF NOT EXISTS biglietti_stato_idx       ON biglietti(stato);
