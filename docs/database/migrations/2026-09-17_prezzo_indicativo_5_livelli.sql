-- Prezzo indicativo dei locali su 5 livelli ($ … $$$$$), come il filtro
-- "Prezzo" del nuovo design della Ricerca (Figma "Ricerca Club_ Sezione Filtri").
--
-- Stato al 17/09/2026: colonna smallint NOT NULL default 1, nessun vincolo;
-- valori presenti solo 2 (37 locali) e 3 (13 locali), pensati su scala 1–3.
--
-- DA APPLICARE A MANO dal SQL Editor di Supabase (l'MCP è in sola lettura).

begin;

-- 1. Vincolo: solo valori da 1 a 5.
alter table public.locali
  drop constraint if exists locali_prezzo_indicativo_range;

alter table public.locali
  add constraint locali_prezzo_indicativo_range
  check (prezzo_indicativo between 1 and 5);

comment on column public.locali.prezzo_indicativo is
  'Fascia di prezzo 1–5 ($ … $$$$$), usata dal filtro Prezzo della Ricerca.';

-- 2. Ricalibrazione dalla vecchia scala 1–3 alla nuova 1–5.
--    Proposta automatica (DECOMMENTARE se va bene): 1 → 1, 2 → 3, 3 → 5.
--    In alternativa assegna i livelli locale per locale con gli UPDATE sotto.
--
-- update public.locali
--    set prezzo_indicativo = case prezzo_indicativo
--                              when 2 then 3
--                              when 3 then 5
--                              else prezzo_indicativo
--                            end;
--
-- Esempio di assegnazione puntuale:
-- update public.locali set prezzo_indicativo = 4 where nome = 'Nome locale';

commit;

-- Controllo:
-- select prezzo_indicativo, count(*) from public.locali group by 1 order by 1;
