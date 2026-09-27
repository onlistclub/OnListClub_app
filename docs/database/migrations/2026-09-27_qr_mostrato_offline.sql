-- ─────────────────────────────────────────────────────────────────────────────
-- Biglietti mostrati all'ingresso SENZA connessione: dato di copertura di rete
-- ─────────────────────────────────────────────────────────────────────────────
-- Richiesta del 27/09/2026: sapere chi si e' fatto scansionare il QR mentre il
-- suo telefono era senza campo, "per capire meglio le persone e il campo di
-- quella zona".
--
-- PERCHE' LO SCRIVE L'APP E NON LO SCANNER. Al momento della scansione il
-- database sente SOLO lo scanner dello staff: il telefono dell'ospite non
-- invia niente, quindi lato server non c'e' modo di sapere se quel telefono
-- avesse campo. L'unico che lo sa e' l'app, e lo racconta dopo, appena torna
-- online (coda in `QrOfflineService`).
--
-- PERCHE' UN ORARIO E NON UN SI'/NO. Chi apre il biglietto in ascensore senza
-- campo e poi entra tranquillo non e' un buco di copertura. Salvando l'ISTANTE
-- il "si'" si ricava in query, incrociandolo con `checked_in_at` che mette lo
-- scanner: sono vicini => e' entrato mentre era senza rete. Il flag booleano
-- resta comodo per i conteggi veloci, ma la verita' e' nel timestamp.
--
-- Da applicare a mano dal SQL editor di Supabase.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.prenotazioni_prevendite
  ADD COLUMN IF NOT EXISTS mostrato_offline    boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS mostrato_offline_at timestamptz;

COMMENT ON COLUMN public.prenotazioni_prevendite.mostrato_offline IS
  'Il QR e'' stato aperto sul telefono mentre l''app era senza connessione. Lo scrive l''app quando torna online, non lo scanner.';
COMMENT ON COLUMN public.prenotazioni_prevendite.mostrato_offline_at IS
  'Quando il QR e'' stato aperto senza connessione. Da incrociare con checked_in_at per capire se l''ingresso e'' avvenuto in assenza di campo.';

-- ── RPC: l'app segna il proprio biglietto ────────────────────────────────────
-- `prenotazioni_prevendite` non e' scrivibile dal client (nessuna policy
-- UPDATE), come per annullamento e telefono: si passa da una SECURITY DEFINER
-- che controlla che la riga sia davvero di chi chiama.
CREATE OR REPLACE FUNCTION public.segna_qr_offline(
  p_id_prenotazione_prevendita uuid,
  p_quando                     timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_utente uuid := auth.uid();
BEGIN
  IF v_utente IS NULL THEN
    RAISE EXCEPTION 'Forbidden: nessun utente autenticato'
      USING ERRCODE = '42501';
  END IF;

  -- Solo la prima volta: se il biglietto e' gia' segnato non si sovrascrive
  -- l'orario, altrimenti una riapertura piu' tardi falserebbe la lettura.
  UPDATE public.prenotazioni_prevendite
     SET mostrato_offline    = true,
         mostrato_offline_at = coalesce(mostrato_offline_at, p_quando)
   WHERE id = p_id_prenotazione_prevendita
     AND id_utente = v_utente
     AND mostrato_offline IS DISTINCT FROM true;
END;
$function$;

REVOKE ALL ON FUNCTION public.segna_qr_offline(uuid, timestamptz) FROM public;
REVOKE ALL ON FUNCTION public.segna_qr_offline(uuid, timestamptz) FROM anon;
GRANT EXECUTE ON FUNCTION public.segna_qr_offline(uuid, timestamptz) TO authenticated;

-- ── Come si legge il dato ────────────────────────────────────────────────────
-- Ingressi avvenuti mentre l'ospite era senza campo, per locale e serata:
-- si considera "senza campo all'ingresso" un QR aperto offline entro 30 minuti
-- dal check-in.
--
-- select l.nome                                as locale,
--        e.nome                                as serata,
--        count(*)                              as ingressi,
--        count(*) filter (
--          where pp.mostrato_offline_at is not null
--            and pp.checked_in_at is not null
--            and abs(extract(epoch from pp.checked_in_at - pp.mostrato_offline_at)) <= 1800
--        )                                     as senza_campo
--   from prenotazioni_prevendite pp
--   join prenotazioni p on p.id = pp.id_prenotazione
--   join eventi       e on e.id = p.id_evento
--   join locali       l on l.id = e.club_id
--  where pp.checked_in_at is not null
--  group by 1, 2
--  order by senza_campo desc;
