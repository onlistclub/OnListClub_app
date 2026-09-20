-- ============================================================
-- Migration: crea tabella pagamenti
-- Data: 2026-04-03
-- ============================================================
--
-- FK polimorfiche: `riferimento_id` punta a biglietti.id oppure
-- a prenotazioni_tavolo.id in base al valore di `tipo`.
-- Non è possibile aggiungere una FK diretta su un riferimento
-- polimorfico; la coerenza è garantita a livello applicativo
-- e dal CHECK su `tipo`.
-- ============================================================

CREATE TABLE IF NOT EXISTS pagamenti (
  id                 UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo               TEXT           NOT NULL
                                      CHECK (tipo IN ('biglietto', 'prenotazione_tavolo')),
  riferimento_id     UUID           NOT NULL,
  importo            NUMERIC(10, 2) NOT NULL CHECK (importo >= 0),
  stato              TEXT           NOT NULL DEFAULT 'in_attesa'
                                      CHECK (stato IN ('in_attesa', 'completato', 'fallito', 'rimborsato')),
  stripe_payment_id  TEXT,
  created_at         TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- Indici per lookup per tipo/riferimento e per stato
CREATE INDEX IF NOT EXISTS pagamenti_riferimento_idx ON pagamenti(tipo, riferimento_id);
CREATE INDEX IF NOT EXISTS pagamenti_stato_idx       ON pagamenti(stato);
CREATE INDEX IF NOT EXISTS pagamenti_stripe_idx      ON pagamenti(stripe_payment_id)
  WHERE stripe_payment_id IS NOT NULL;
