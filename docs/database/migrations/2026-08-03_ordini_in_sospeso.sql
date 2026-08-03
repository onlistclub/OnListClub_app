-- ============================================================
-- Carrello: ordini lasciati in sospeso
-- Data: 2026-08-03
--
-- A COSA SERVE
-- Quando l'utente entra nella lista ticket di una serata ("Acquista il tuo
-- ticket") l'ordine viene messo in sospeso QUI, subito. Se poi esce senza
-- concludere, lo ritrova nel carrello ("Completa ordine") e il pallino blu
-- sulla footer lo avvisa.
--
-- PERCHE' SUL DB E NON SUL DISPOSITIVO
--   1. Le 48 ore di validita' hanno bisogno di un orologio affidabile:
--      l'ora del telefono si cambia dalle impostazioni, now() no.
--   2. L'utente ritrova il sospeso anche cambiando telefono o reinstallando.
--   3. Sono i dati sugli ordini ABBANDONATI: quale ticket di quale club la
--      gente stava per comprare e non ha comprato. Per un MVP che nasce per
--      raccogliere dati e' fra le informazioni piu' utili.
--
-- SCADENZA
-- Non si cancella niente: la riga resta come storico, e' la LETTURA a
-- filtrare `created_at > now() - interval '48 hours'`. Una pulizia periodica
-- si potra' aggiungere quando attiveremo pg_cron per le notifiche.
--
-- GRANULARITA'
-- Una riga per (utente, evento), non per singolo ticket: al momento in cui
-- l'ordine entra in sospeso l'utente ha scelto la SERATA, non ancora quale
-- ticket. La card nel carrello mostra il nome del club e riporta alla lista.
--
-- DA ESEGUIRE nel SQL editor di Supabase (o via MCP).
-- ============================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.ordini_in_sospeso (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  id_utente uuid NOT NULL,
  id_evento uuid NOT NULL,
  -- false = l'utente non ha ancora aperto il carrello da quando ha lasciato
  -- l'ordine in sospeso => pallino blu acceso. Torna false ogni volta che
  -- rientra nella lista ticket e riesce senza concludere.
  visto boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ordini_in_sospeso_pkey PRIMARY KEY (id),
  -- Rientrare sulla stessa serata AGGIORNA il sospeso, non ne crea un altro.
  CONSTRAINT ordini_in_sospeso_utente_evento_key UNIQUE (id_utente, id_evento),
  CONSTRAINT ordini_in_sospeso_id_utente_fkey
    FOREIGN KEY (id_utente) REFERENCES public.utenti(id) ON DELETE CASCADE,
  CONSTRAINT ordini_in_sospeso_id_evento_fkey
    FOREIGN KEY (id_evento) REFERENCES public.eventi(id) ON DELETE CASCADE
);

COMMENT ON TABLE public.ordini_in_sospeso IS
  'Ordini lasciati a meta'' nella scelta ticket. Validi 48h (filtro in '
  'lettura, le righe restano come storico degli abbandoni).';

-- La lettura e' sempre "i miei sospesi, dal piu' recente".
CREATE INDEX IF NOT EXISTS ordini_in_sospeso_utente_data_idx
  ON public.ordini_in_sospeso (id_utente, created_at DESC);

-- ------------------------------------------------------------
-- RLS: ognuno vede e tocca SOLO i propri sospesi.
-- WITH CHECK esplicito, TO authenticated (stessa linea del hardening
-- 2026-05-31: anon non deve nemmeno valutare la policy).
-- ------------------------------------------------------------
ALTER TABLE public.ordini_in_sospeso ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ordini_in_sospeso_proprietario
  ON public.ordini_in_sospeso;
CREATE POLICY ordini_in_sospeso_proprietario ON public.ordini_in_sospeso
  FOR ALL
  TO authenticated
  USING      (id_utente = auth.uid())
  WITH CHECK (id_utente = auth.uid());

COMMIT;

-- ------------------------------------------------------------
-- VERIFICA
-- ------------------------------------------------------------
-- I miei sospesi ancora validi:
-- SELECT o.id, e.nome AS serata, l.nome AS club, o.visto, o.created_at
-- FROM public.ordini_in_sospeso o
-- JOIN public.eventi e ON e.id = o.id_evento
-- JOIN public.locali l ON l.id = e.club_id
-- WHERE o.id_utente = auth.uid()
--   AND o.created_at > now() - interval '48 hours'
-- ORDER BY o.created_at DESC;
--
-- Storico abbandoni per club (le righe restano anche dopo le 48h):
-- SELECT l.nome, count(*) AS abbandoni
-- FROM public.ordini_in_sospeso o
-- JOIN public.eventi e ON e.id = o.id_evento
-- JOIN public.locali l ON l.id = e.club_id
-- GROUP BY l.nome
-- ORDER BY abbandoni DESC;
