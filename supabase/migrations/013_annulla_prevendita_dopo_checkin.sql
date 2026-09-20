-- =============================================================================
-- OnList Club — Non si annulla una prevendita già entrata (013)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
-- DOPO la 011 (che introduce prenotazioni_prevendite.checked_in_at).
--
-- IL PROBLEMA
-- `annulla_prevendita` (docs/database/migration_annulla_prevendita.sql) annulla
-- qualunque prenotazione dell'utente che non sia già annullata. Nessun controllo
-- sull'ingresso. Quindi:
--
--   1. l'ospite entra, lo staff scansiona il QR;
--   2. dal telefono, anche mezz'ora dopo, tocca "Annulla prevendita";
--   3. stato -> 'annullata', e il trigger trg_restore_prevendita_stock rimette
--      il posto a magazzino;
--   4. il locale rivende quel posto a qualcuno che è già dentro.
--
-- In una serata al completo è il tipo di errore che si paga alla porta.
--
-- LA CORREZIONE
-- La RPC rifiuta se ANCHE UN SOLO biglietto dell'ordine risulta entrato. Vale
-- anche per l'acquisto multi-intestatario, il giorno in cui verrà acceso: se
-- uno del gruppo è dentro, l'ordine non si annulla più per nessuno.
--
-- Il controllo guarda due posti, non uno:
--   - `prenotazioni_prevendite.checked_in_at`, la fonte dalla 011 in poi;
--   - un `scan_logs` VALID per quel biglietto, che è la fonte storica e resta
--     valida anche se la 012 (policy di UPDATE per i gestori) non fosse ancora
--     applicata e il timbro non fosse stato scritto.
-- Un ingresso registrato in uno qualsiasi dei due basta a bloccare.
--
-- L'errore ha un SQLSTATE suo (P0003) perché l'app deve poter dire "sei già
-- entrato" invece del generico "prenotazione non trovata" (vedi
-- lib/core/services/orders_service.dart).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.annulla_prevendita(p_id_prenotazione uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_entrato boolean;
BEGIN
  -- Il controllo dell'ingresso viene prima dell'UPDATE e sulla prenotazione
  -- dell'utente che chiama: un id altrui non rivela nulla, cade comunque
  -- nell'errore "non trovata" dell'UPDATE più sotto.
  SELECT EXISTS (
    SELECT 1
    FROM public.prenotazioni_prevendite pp
    JOIN public.prenotazioni pr ON pr.id = pp.id_prenotazione
    WHERE pp.id_prenotazione = p_id_prenotazione
      AND pr.id_utente = auth.uid()
      AND (
        pp.checked_in_at IS NOT NULL
        OR EXISTS (
          SELECT 1 FROM public.scan_logs sl
          WHERE sl.ticket_id = pp.id
            AND sl.status_result = 'VALID'
        )
      )
  ) INTO v_entrato;

  IF v_entrato THEN
    RAISE EXCEPTION 'Prevendita già utilizzata all''ingresso: non è più annullabile'
      USING ERRCODE = 'P0003';
  END IF;

  UPDATE public.prenotazioni
     SET stato = 'annullata'
   WHERE id = p_id_prenotazione
     AND id_utente = auth.uid()
     AND stato IS DISTINCT FROM 'annullata';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prenotazione non trovata o gia'' annullata'
      USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.annulla_prevendita(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.annulla_prevendita(uuid) TO authenticated;

COMMENT ON FUNCTION public.annulla_prevendita(uuid) IS
  'Annulla una prenotazione dell''utente chiamante. Rifiuta (P0003) se un biglietto dell''ordine è già entrato: il posto non deve tornare a magazzino.';

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- Verifiche post-applicazione
-- =============================================================================
-- 1) Un biglietto NON entrato si annulla ancora (nessuna regressione):
--    con il JWT dell'utente proprietario,
--    SELECT public.annulla_prevendita('<id_prenotazione mai scansionata>');
--    -> ok; poi controlla che lo stock sia risalito:
--    SELECT quantita_disponibile FROM public.prevendite WHERE id_prevendita = '<...>';
--
-- 2) Un biglietto entrato NON si annulla più:
--    scansiona un QR, poi
--    SELECT public.annulla_prevendita('<quella prenotazione>');
--    -> ERRORE P0003, e soprattutto:
--    SELECT stato FROM public.prenotazioni WHERE id = '<...>';  -- 'confermata'
--    SELECT quantita_disponibile FROM public.prevendite WHERE id_prevendita = '<...>';
--    -> INVARIATA. È questo il numero che prima si sporcava.
--
-- 3) Nell'app: aperto un biglietto già scansionato, al posto del pulsante
--    "ANNULLA PREVENDITA" deve comparire la scritta "GIÀ UTILIZZATO".
-- =============================================================================
-- Resta una decisione aperta: annullare a serata FINITA da parte di chi non è
-- mai entrato. Oggi è permesso, e rimette a magazzino un posto di una serata
-- passata (numeri di vendita e incasso che cambiano a posteriori). Non l'ho
-- bloccato perché è una scelta commerciale, non una svista: se la vuoi, la
-- condizione da aggiungere qui sopra è
--    AND e.inizio_evento > now()
-- con il join su eventi, e va decisa insieme alla politica di rimborso.
