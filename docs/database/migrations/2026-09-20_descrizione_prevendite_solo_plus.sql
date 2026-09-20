-- ─────────────────────────────────────────────────────────────────────────────
-- Prevendite: la descrizione contiene SOLO le offerte, una per riga, con "+"
-- ─────────────────────────────────────────────────────────────────────────────
-- Doc correzioni design del 20/09/2026, sezione "Lista Ticket":
--   «bisogna dal DB togliere la parola "Ingresso" e lasciare solo "+…"»
--
-- Formato di arrivo (e' gia' quello di due righe scritte a mano nel DB):
--
--   + 2 drink omaggio
--   + Salta fila OnListClub PASS
--   + Ticket guardaroba omaggio
--
-- Da questo formato l'app ricava DA SOLA (funzione `offertePlus` in
-- lib/widgets/ticket_cards.dart):
--   - l'elenco sotto "Dettagli" nella schermata del ticket;
--   - il numero del "+ N Plus" accanto a "Ticket x 1" (qui: "+ 3 Plus").
-- Non serve nessuna colonna in piu' e non c'e' niente da tenere allineato a
-- mano: bastano i "+" scritti qui dentro.
--
-- NOTA: l'app funziona gia' anche PRIMA di questa migration — il pezzo che sta
-- davanti al primo "+" ("Ingresso ridotto donna + drink") viene ignorato sia
-- nell'elenco sia nel conteggio. Questa migration serve a pulire i dati, non a
-- far funzionare la schermata.
--
-- Applicare a mano dal SQL editor di Supabase (l'MCP e' in sola lettura).
-- ─────────────────────────────────────────────────────────────────────────────

-- 0. Come sono messe adesso le descrizioni (da lanciare prima, per controllo).
--    select descrizione, tipo, count(*)
--      from prevendite group by descrizione, tipo order by count(*) desc;

begin;

-- ── Donna ────────────────────────────────────────────────────────────────────
update prevendite set descrizione = '+ 1 drink omaggio'
 where descrizione in ('Ridotto donna + drink', 'Ingresso ridotto donna + drink');

update prevendite set descrizione = '+ 2 drink omaggio'
 where descrizione = 'Ingresso ridotto donna + 2 drink omaggio';

-- ── Normale ──────────────────────────────────────────────────────────────────
update prevendite set descrizione = '+ Welcome drink'
 where descrizione = 'Welcome drink';

update prevendite set descrizione = '+ 1 drink omaggio'
 where descrizione = 'Ingresso + 1 drink';

update prevendite set descrizione = '+ 2 drink omaggio'
 where descrizione = 'Ingresso + 2 drink omaggio';

-- ── VIP ──────────────────────────────────────────────────────────────────────
update prevendite
   set descrizione = E'+ Ingresso prioritario\n+ 2 drink omaggio'
 where descrizione = 'Ingresso prioritario + 2 drink';

update prevendite
   set descrizione = E'+ Ingresso prioritario\n+ Tavolo riservato\n+ 2 drink omaggio'
 where descrizione = 'Prioritario + tavolo + 2 drink';

update prevendite
   set descrizione = E'+ Salta fila OnListClub PASS\n+ 2 drink omaggio'
 where descrizione = 'Skip line + 2 drink omaggio';

commit;

-- ── Uomo: DECISIONE DA PRENDERE ──────────────────────────────────────────────
-- "Uomo" (450 righe) e "Ingresso uomo" (200) non sono offerte, sono il tipo di
-- ticket: ripetuti sotto "Dettagli" non dicono niente. Due strade:
--
--   a) svuotare il campo -> sotto "Dettagli" non compare nulla e non compare
--      il "+ N Plus" (questo ticket non ha offerte);
--   b) scriverci l'offerta vera, se ce n'e' una (es. '+ 1 drink omaggio').
--
-- Lasciate commentate: scegli tu quale lanciare.
--
-- update prevendite set descrizione = '' where descrizione in ('Uomo', 'Ingresso uomo');
-- update prevendite set descrizione = '+ 1 drink omaggio' where descrizione in ('Uomo', 'Ingresso uomo');

-- ── Righe di test ────────────────────────────────────────────────────────────
-- '[SEED_TEST_2026] Ingresso ridotto donna + drink' (249 righe) NON viene
-- toccata: il prefisso [SEED_TEST_2026] serve a ritrovare e ripulire i dati
-- finti, riscrivendo la descrizione lo si perderebbe. Se vuoi normalizzare
-- anche quelle tenendo il marcatore:
--
-- update prevendite
--    set descrizione = '[SEED_TEST_2026] + 1 drink omaggio'
--  where descrizione = '[SEED_TEST_2026] Ingresso ridotto donna + drink';

-- ── Verifica ─────────────────────────────────────────────────────────────────
-- select descrizione,
--        length(descrizione) - length(replace(descrizione, '+', '')) as plus,
--        count(*)
--   from prevendite group by descrizione order by count(*) desc;
