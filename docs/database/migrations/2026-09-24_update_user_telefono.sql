-- ─────────────────────────────────────────────────────────────────────────────
-- Cambio del numero di telefono dal Profilo
-- ─────────────────────────────────────────────────────────────────────────────
-- Punto 2.1 del documento "Specifiche Modifiche App": l'utente deve poter
-- modificare il proprio numero dalla schermata Profilo.
--
-- Il numero NON sta su `utenti`: sta su `utenti_numeri_telefono`, che il client
-- non scrive direttamente. In registrazione la scrittura passa da
-- `register_user_transaction` (SECURITY DEFINER); qui serve l'equivalente per
-- il solo aggiornamento, con le stesse regole:
--   - solo l'utente loggato tocca i propri numeri (auth.uid());
--   - il numero viene normalizzato in E.164 come fa la RPC di registrazione;
--   - il paese si risolve da ISO su `paesi.iso_code`.
--
-- Il numero vecchio non viene cancellato: smette solo di essere primario, cosi'
-- lo storico resta e non si perde niente per sbaglio. Il numero nuovo entra
-- come primario e NON verificato (is_verified = false): la verifica, quando
-- arrivera', e' un flusso a parte.
--
-- Da applicare a mano dal SQL editor di Supabase.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.update_user_telefono(
  p_telefono    text,
  p_country_iso text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_utente     uuid        := auth.uid();
  v_country_id uuid        := null;
  v_e164       text;
  v_now        timestamptz := now();
BEGIN
  -- ── Hardening: si tocca solo il proprio numero ──
  IF v_utente IS NULL THEN
    RAISE EXCEPTION 'Forbidden: nessun utente autenticato'
      USING ERRCODE = '42501';
  END IF;

  IF p_telefono IS NULL OR length(trim(p_telefono)) < 7 THEN
    RAISE EXCEPTION 'Telefono non valido';
  END IF;

  -- ── Lookup paese (stessa tabella/colonna della RPC di registrazione) ──
  SELECT id INTO v_country_id
  FROM public.paesi
  WHERE upper(iso_code) = upper(coalesce(p_country_iso, ''))
  LIMIT 1;

  -- ── Sanitizzazione E.164 ──
  v_e164 := replace(coalesce(p_telefono, ''), ' ', '');
  IF v_e164 = '' THEN
    RAISE EXCEPTION 'Telefono non valido';
  END IF;
  IF v_e164 !~ '^\+' THEN
    v_e164 := '+' || v_e164;
  END IF;

  -- ── Gli altri numeri smettono di essere primari ──
  UPDATE public.utenti_numeri_telefono
     SET is_primary = false,
         updated_at = v_now
   WHERE id_utente = v_utente
     AND telefono <> v_e164;

  -- ── Il nuovo entra (o torna) come primario ──
  INSERT INTO public.utenti_numeri_telefono
    (id_utente, country_id, telefono, is_primary, is_verified, created_at)
  VALUES
    (v_utente, v_country_id, v_e164, true, false, v_now)
  ON CONFLICT (id_utente, telefono) DO UPDATE
    SET country_id  = EXCLUDED.country_id,
        is_primary  = true,
        is_verified = false,
        updated_at  = v_now;

  RETURN json_build_object(
    'telefono',   v_e164,
    'country_id', v_country_id,
    'status',     'ok'
  );
END;
$function$;

-- Eseguibile solo da utenti loggati.
REVOKE ALL ON FUNCTION public.update_user_telefono(text, text) FROM public;
REVOKE ALL ON FUNCTION public.update_user_telefono(text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_user_telefono(text, text) TO authenticated;

-- ── Verifica ─────────────────────────────────────────────────────────────────
-- select proname, pg_get_function_identity_arguments(oid)
--   from pg_proc where proname = 'update_user_telefono';
