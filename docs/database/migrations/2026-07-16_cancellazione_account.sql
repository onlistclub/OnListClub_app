-- =============================================================================
--  Cancellazione account — supporto DB
--  Data:    2026-07-16
--  Target:  Supabase Postgres del progetto OnList Club (ref: ppbxhedbludoqnagzugm)
--  Come:    eseguire l'intero file dal SQL Editor di Supabase Studio
--           (tutto è idempotente: si può rilanciare senza danni).
--
--  Contesto: l'utente avvia la cancellazione dall'app (tile nel profilo), riceve
--  un'email con un link monouso e conferma sul sito (/auth/delete-account).
--  Le Edge Functions request-account-deletion e confirm-account-deletion sono la
--  controparte applicativa di questo file.
--
--  Cosa fa:
--    1  Tabella richieste_cancellazione: i token monouso inviati per email.
--       In DB finisce solo l'hash SHA-256 del token, mai il token in chiaro:
--       chi legge il DB non può fabbricare un link valido.
--    2  ordini.utente_id diventa NULLABLE. Serve al punto 3: gli ordini vanno
--       conservati per i conti, ma slegati dalla persona, e oggi la colonna è
--       NOT NULL.
--    3  Funzione anonimizza_utente(): esegue la cancellazione in UNA
--       transazione. Distingue i dati contabili (righe conservate, ripulite dai
--       riferimenti personali) dai dati personali (righe eliminate).
--
--  ATTENZIONE — nel DB non esiste NESSUNA foreign key verso auth.users, quindi
--  niente cascata: eliminare l'utente da auth lascerebbe in piedi tutti i suoi
--  dati. Ogni tabella va trattata a mano, ed è esattamente quello che fa
--  anonimizza_utente(). Se in futuro aggiungi una tabella con dati utente,
--  DEVI aggiungerla anche qui, altrimenti la cancellazione la dimentica.
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
--  1 — Richieste di cancellazione (token monouso)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.richieste_cancellazione (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_utente   uuid NOT NULL,
  -- SHA-256 in hex del token spedito per email. Mai il token in chiaro.
  token_hash  text NOT NULL,
  scadenza    timestamptz NOT NULL,
  -- Valorizzata quando il token viene consumato: rende il link monouso.
  usata_il    timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS richieste_cancellazione_token_hash_key
  ON public.richieste_cancellazione (token_hash);

-- Usato sia per il rate limit sia per la pulizia in anonimizza_utente().
CREATE INDEX IF NOT EXISTS richieste_cancellazione_id_utente_idx
  ON public.richieste_cancellazione (id_utente, created_at DESC);

-- RLS attiva e NESSUNA policy: la tabella è invisibile ad anon e authenticated.
-- Ci accedono solo le Edge Functions con service_role, che bypassa la RLS.
ALTER TABLE public.richieste_cancellazione ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.richieste_cancellazione FROM anon, authenticated;


-- ─────────────────────────────────────────────────────────────────────────────
--  2 — ordini.utente_id diventa nullable
-- ─────────────────────────────────────────────────────────────────────────────
--  NULL = ordine di un utente cancellato. La riga resta per i conti del locale
--  (importo, stato, riferimenti Stripe) ma non è più riconducibile a nessuno.

ALTER TABLE public.ordini ALTER COLUMN utente_id DROP NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────────
--  3 — anonimizza_utente()
-- ─────────────────────────────────────────────────────────────────────────────
--  Cancella l'utente dalle tabelle applicative. NON tocca auth.users: quello lo
--  fa la Edge Function con l'admin API subito dopo, così sessioni e identity
--  OAuth vengono ripulite da Supabase stesso.
--
--  plpgsql = una sola transazione implicita: o passa tutto, o non passa niente.
--  Nessuno stato a metà con l'account mezzo cancellato.

CREATE OR REPLACE FUNCTION public.anonimizza_utente(p_id_utente uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_id_utente IS NULL THEN
    RAISE EXCEPTION 'anonimizza_utente: p_id_utente obbligatorio';
  END IF;

  -- ── Dati contabili: la riga resta, i riferimenti personali no ──────────────

  -- nome_cliente e nome/cognome/data_nascita sono NOT NULL: non si azzerano,
  -- si sostituiscono con un segnaposto.
  UPDATE public.prenotazioni
     SET id_utente    = NULL,
         nome_cliente = 'Utente eliminato',
         telefono     = NULL,
         note         = NULL
   WHERE id_utente = p_id_utente;

  UPDATE public.prenotazioni_prevendite
     SET id_utente    = NULL,
         nome         = 'Utente',
         cognome      = 'eliminato',
         data_nascita = '1900-01-01'
   WHERE id_utente = p_id_utente;

  UPDATE public.prenotazioni_tavolo
     SET id_utente    = NULL,
         nome_cliente = 'Utente eliminato'
   WHERE id_utente = p_id_utente;

  UPDATE public.ordini
     SET utente_id = NULL
   WHERE utente_id = p_id_utente;

  -- Analytics: si conserva l'evento aggregato, si perde la persona.
  UPDATE public.analytics_events SET user_id = NULL WHERE user_id = p_id_utente;
  UPDATE public.activity_events  SET user_id = NULL WHERE user_id = p_id_utente;

  -- ── Dati personali: via del tutto ──────────────────────────────────────────

  DELETE FROM public.notifiche              WHERE utente_id = p_id_utente;
  DELETE FROM public.preferiti              WHERE id_utente = p_id_utente;
  DELETE FROM public.utenti_numeri_telefono WHERE id_utente = p_id_utente;
  -- email_logs contiene indirizzo, nome e corpo delle email: è tutto personale.
  DELETE FROM public.email_logs             WHERE utente_id = p_id_utente;
  DELETE FROM public.richieste_cancellazione WHERE id_utente = p_id_utente;

  DELETE FROM public.utenti WHERE id = p_id_utente;
END;
$$;

-- Eseguibile SOLO da service_role (le Edge Functions). Un utente loggato non
-- deve poterla invocare: il permesso di cancellare passa dal token via email.
REVOKE ALL ON FUNCTION public.anonimizza_utente(uuid) FROM public, anon, authenticated;
