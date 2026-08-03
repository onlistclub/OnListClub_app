-- =============================================================================
-- Punto 12 del documento "modifiche versione 1.1"
-- "riguardare bene le sezioni con scritto Welcome Drink poiche' devono essere
--  ben organizzati, e soprattutto NON devono essere uguali
--  (modifica di dati del Database, non riguarda design)"
-- =============================================================================
--
-- PROBLEMA
-- Nella schermata biglietto ci sono DUE punti che mostrano cosa e' incluso:
--   1. la riga corta in alto a destra, accanto a "Ticket x 1"
--   2. l'elenco sotto il titolo "Dettagli"
-- Oggi leggono ENTRAMBI `prevendite.descrizione`, quindi stampano la stessa
-- identica scritta ("Welcome drink" due volte).
--
-- SOLUZIONE (scelta d di Luca)
--   * prevendite.riepilogo   -> riga CORTA, max 1 riga: solo il CONTEGGIO delle
--                               aggiunte. Es. "+ 2 drink, + 2 guardaroba"
--   * prevendite.descrizione -> elenco COMPLETO di aggiunte e omaggi, che
--                               finisce sotto "Dettagli". Una voce per riga
--                               (a capo) oppure separate da ';'.
--
-- COMPATIBILITA'
-- L'app funziona anche PRIMA di applicare questa migration: se la colonna
-- `riepilogo` non esiste o e' vuota, ricade su `descrizione` (comportamento
-- di oggi). Nessuna policy RLS da toccare: aggiungere una colonna non cambia
-- chi puo' leggere la tabella.
--
-- DA ESEGUIRE A MANO nel SQL editor di Supabase (l'MCP e' read-only).
-- =============================================================================

ALTER TABLE public.prevendite
  ADD COLUMN IF NOT EXISTS riepilogo varchar(60);

COMMENT ON COLUMN public.prevendite.riepilogo IS
  'Riga corta (max 1 riga) mostrata in alto a destra nella card e accanto a '
  '"Ticket x 1". Solo il conteggio delle aggiunte, es. "+ 2 drink". '
  'Se NULL/vuota l''app ricade su descrizione.';

COMMENT ON COLUMN public.prevendite.descrizione IS
  'Elenco COMPLETO di aggiunte e omaggi, mostrato sotto "Dettagli". '
  'Una voce per riga (a capo) oppure separate da '';''.';

-- -----------------------------------------------------------------------------
-- Backfill: chi non ha ancora un riepilogo dedicato continua a vedere qualcosa.
-- Prendiamo solo la PRIMA voce della descrizione e la tronchiamo, cosi' resta
-- davvero su una riga sola invece di ripetere tutto l'elenco.
-- -----------------------------------------------------------------------------
UPDATE public.prevendite
SET riepilogo = left(
      btrim(split_part(replace(descrizione, ';', E'\n'), E'\n', 1)),
      60
    )
WHERE riepilogo IS NULL
  AND descrizione IS NOT NULL
  AND btrim(descrizione) <> '';

-- -----------------------------------------------------------------------------
-- VERIFICA: le due colonne non devono piu' essere uguali.
-- -----------------------------------------------------------------------------
-- SELECT tipo, prezzo, riepilogo, descrizione
-- FROM public.prevendite
-- ORDER BY tipo;
--
-- Righe ancora "gemelle" (da sistemare a mano con l'esempio qui sotto):
-- SELECT id_prevendita, tipo, riepilogo
-- FROM public.prevendite
-- WHERE btrim(coalesce(riepilogo, '')) = btrim(coalesce(descrizione, ''));

-- -----------------------------------------------------------------------------
-- ESEMPIO di come vanno riempiti i due campi (adattare id/tipo).
-- Nota: nel client la descrizione viene spezzata su a-capo e ';', quindi
-- entrambi i formati vanno bene.
-- -----------------------------------------------------------------------------
-- UPDATE public.prevendite
-- SET riepilogo   = '+ 2 drink',
--     descrizione = E'2 drink inclusi\nGuardaroba gratuito\nIngresso prioritario fino alle 00:30'
-- WHERE tipo = 'Normale' AND id_evento = '<uuid-serata>';
--
-- UPDATE public.prevendite
-- SET riepilogo   = '+ 2 drink, + 1 guardaroba',
--     descrizione = E'2 drink inclusi\n1 posto guardaroba omaggio\nAccesso area VIP'
-- WHERE tipo = 'Vip' AND id_evento = '<uuid-serata>';
