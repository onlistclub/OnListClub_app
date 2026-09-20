-- =============================================================================
-- OnList Club — Validazione Sold Out a livello di evento (005)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
--
-- Modifica il trigger function `fn_decrement_prevendita_stock` per controllare
-- non solo lo stock della singola prevendita, ma anche se la somma di tutti
-- i biglietti attivi venduti supera la capienza totale dell'evento (ingressi_previsti).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_decrement_prevendita_stock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_evento_id          uuid;
  v_ingressi_previsti  integer;
  v_biglietti_attivi   integer;
  v_remaining          integer;
BEGIN
  -- 1. Recupera l'evento e la capienza (ingressi_previsti)
  SELECT pv.id_evento, e.ingressi_previsti
  INTO v_evento_id, v_ingressi_previsti
  FROM public.prevendite pv
  JOIN public.eventi e ON e.id = pv.id_evento
  WHERE pv.id_prevendita = NEW.id_prevendita;

  -- 2. Se è impostato un limite di capienza sull'evento (> 0)
  IF v_ingressi_previsti IS NOT NULL AND v_ingressi_previsti > 0 THEN
    -- Conta i biglietti attivi già emessi per questo evento (escludendo quelli con prenotazione annullata)
    SELECT COUNT(*)
    INTO v_biglietti_attivi
    FROM public.prenotazioni_prevendite pp
    JOIN public.prenotazioni pr ON pr.id = pp.id_prenotazione
    JOIN public.prevendite pv ON pv.id_prevendita = pp.id_prevendita
    WHERE pv.id_evento = v_evento_id
      AND pr.stato <> 'annullata';

    -- Se abbiamo raggiunto o superato il limite, vieta l'acquisto
    IF v_biglietti_attivi >= v_ingressi_previsti THEN
      RAISE EXCEPTION 'Evento sold out: capienza massima raggiunta (%)', v_ingressi_previsti
        USING ERRCODE = 'P0002';
    END IF;
  END IF;

  -- 3. Continua con il decremento dello stock della specifica prevendita
  UPDATE public.prevendite
  SET quantita_disponibile = quantita_disponibile - 1
  WHERE id_prevendita = NEW.id_prevendita
    AND quantita_disponibile > 0
  RETURNING quantita_disponibile INTO v_remaining;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prevendita esaurita (id=%)', NEW.id_prevendita
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.fn_decrement_prevendita_stock() IS
  'Controlla e decrementa lo stock. Impedisce l''acquisto se l''evento ha raggiunto la capienza massima (ingressi_previsti).';
