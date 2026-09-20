-- =============================================================================
-- OnList Club — Verifiche delle migration 011 → 015
--
-- Da incollare nell'SQL editor del progetto ppbxhedbludoqnagzugm.
-- Ogni blocco è indipendente: esegui la selezione che ti serve.
-- Sotto ogni query c'è il risultato ATTESO. Se non combacia, fermati lì.
--
-- I controlli che NON si fanno in SQL (servono un JWT o l'app in mano) sono
-- raccolti in fondo, sezione Z.
-- =============================================================================


-- ═══════════════════════════════════════════════════════════════════════════
-- A. PRIMA di applicare qualsiasi cosa
-- ═══════════════════════════════════════════════════════════════════════════

-- A1. my_club_id() copre anche lo staff, non solo i gestori?
--     Se false, la 007 non è mai stata applicata: applicala PRIMA della 012,
--     altrimenti gli account staff vedranno una dashboard vuota.
SELECT prosrc LIKE '%public.staff%' AS my_club_id_copre_staff
FROM pg_proc
WHERE proname = 'my_club_id';
-- atteso: true

-- A2. Esistono gli oggetti su cui lavorano le migration?
SELECT
  to_regclass('public.activity_events')          IS NOT NULL AS activity_events,
  to_regclass('public.analytics_events')         IS NOT NULL AS analytics_events,
  to_regclass('public.v_prenotazioni_dashboard') IS NOT NULL AS vista_prenotazioni,
  to_regclass('public.v_eventi_dashboard')       IS NOT NULL AS vista_eventi;
-- atteso: tutte true.
-- activity_events false = il file 20260710120000 del sito non è mai stato
-- eseguito, quindi il tracciamento del sito non ha mai scritto niente.


-- ═══════════════════════════════════════════════════════════════════════════
-- B. Dopo la 011 — il check-in è del biglietto
-- ═══════════════════════════════════════════════════════════════════════════

-- B1. La colonna c'è.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'prenotazioni_prevendite'
  AND column_name = 'checked_in_at';
-- atteso: una riga, timestamp with time zone

-- B2. Il backfill non ha inventato ingressi: i due numeri devono coincidere.
SELECT
  (SELECT count(*) FROM public.prenotazioni_prevendite WHERE checked_in_at IS NOT NULL) AS biglietti_timbrati,
  (SELECT count(DISTINCT ticket_id) FROM public.scan_logs WHERE status_result = 'VALID' AND ticket_id IS NOT NULL) AS scansioni_valide;
-- atteso: due numeri uguali

-- B3. Ordini con più biglietti: ognuno deve avere il PROPRIO check-in.
--     Oggi l'app crea ordini da un biglietto solo, quindi può tornare vuota:
--     serve dal giorno in cui accendi l'acquisto multi-intestatario.
SELECT prenotazione_id, prenotazione_prevendita_id, nome, cognome, primo_check_in_at
FROM public.v_prenotazioni_dashboard
WHERE prenotazione_id IN (
  SELECT id_prenotazione
  FROM public.prenotazioni_prevendite
  GROUP BY id_prenotazione
  HAVING count(*) > 1
)
ORDER BY prenotazione_id, cognome;
-- atteso: scansionato UN biglietto del gruppo, gli altri restano NULL

-- B4. Il KPI degli ingressi non è più uguale al venduto.
SELECT evento_nome, biglietti_venduti, prenotazioni_confermate, checkin_effettuati
FROM public.v_eventi_dashboard
WHERE inizio_evento > now() - interval '30 days'
ORDER BY inizio_evento DESC;
-- atteso: checkin_effettuati <= biglietti_venduti, e diverso da
--         prenotazioni_confermate (che conta gli ordini pagati)


-- ═══════════════════════════════════════════════════════════════════════════
-- C. Dopo la 012 — la vista non scavalca più la RLS
-- ═══════════════════════════════════════════════════════════════════════════

-- C1. La vista è security_invoker.
SELECT relname, reloptions
FROM pg_class
WHERE relkind = 'v'
  AND relname IN ('v_prenotazioni_dashboard', 'v_eventi_dashboard', 'v_utenti_profilo');
-- atteso: reloptions contiene {security_invoker=true} su tutte e tre

-- C2. La RLS è accesa sulle tabelle che la vista attraversa.
SELECT relname, relrowsecurity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND relname IN ('prenotazioni', 'prenotazioni_prevendite', 'prevendite');
-- atteso: true su prenotazioni e prenotazioni_prevendite
--         (prevendite può restare false: non contiene dati personali)

-- C3. Le policy dei gestori esistono davvero.
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname IN (
    'gestori_select_prenotazioni',
    'gestori_select_prenotazioni_prevendite',
    'gestori_update_checkin',
    'gestori_select_prevendite'
  )
ORDER BY tablename, policyname;
-- atteso: 4 righe, tutte su {authenticated}

-- C4. Panoramica di tutte le policy sulle tabelle delle prenotazioni,
--     per vedere se qualcuna è più larga del previsto.
SELECT tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('prenotazioni', 'prenotazioni_prevendite', 'prevendite', 'scan_logs')
ORDER BY tablename, cmd, policyname;
-- da leggere a occhio: nessuna SELECT con qual = true


-- ═══════════════════════════════════════════════════════════════════════════
-- D. Dopo la 013 — non si annulla un biglietto già entrato
-- ═══════════════════════════════════════════════════════════════════════════

-- D1. La funzione è quella nuova.
SELECT prosrc LIKE '%P0003%' AS blocca_gia_entrati
FROM pg_proc
WHERE proname = 'annulla_prevendita';
-- atteso: true

-- D2. Prova reale. Prendi un biglietto GIÀ scansionato e la sua prenotazione:
SELECT pp.id AS biglietto, pp.id_prenotazione, pp.checked_in_at,
       pv.id_prevendita, pv.quantita_disponibile AS stock_prima
FROM public.prenotazioni_prevendite pp
JOIN public.prevendite pv ON pv.id_prevendita = pp.id_prevendita
WHERE pp.checked_in_at IS NOT NULL
LIMIT 1;
-- poi, con il JWT di QUELL'utente (non da SQL editor: vedi Z3),
-- chiama annulla_prevendita e ricontrolla:
--   SELECT stato FROM public.prenotazioni WHERE id = '<id_prenotazione>';
--   -> 'confermata', NON 'annullata'
--   SELECT quantita_disponibile FROM public.prevendite WHERE id_prevendita = '<...>';
--   -> INVARIATA rispetto a stock_prima. È questo il numero che si sporcava.


-- ═══════════════════════════════════════════════════════════════════════════
-- E. Dopo la 014 — la cima del funnel
-- ═══════════════════════════════════════════════════════════════════════════

-- E1. Le due policy di scrittura sono quelle nuove.
SELECT policyname, cmd, roles, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'analytics_events'
ORDER BY policyname;
-- atteso: analytics_events_insert_anon           {anon}          (user_id IS NULL)
--         analytics_events_insert_authenticated  {authenticated} (user_id IS NULL OR user_id = auth.uid())
--         e NESSUNA "Allow authenticated inserts"

-- E2. Arrivano davvero gli eventi prima del login.
--     Da eseguire DOPO aver aperto l'app senza fare accesso (vedi Z1).
SELECT event_name, user_id, platform, app_version, created_at
FROM public.analytics_events
WHERE created_at > now() - interval '15 minutes'
ORDER BY created_at;
-- atteso: righe con user_id NULL (app_open, gps_permission, screen_* di login).
--         Prima della 014 questa lista era vuota.

-- E3. La versione dell'app non è più scritta a mano (dopo la build nuova).
SELECT app_version, count(*) AS eventi, max(created_at) AS ultimo
FROM public.analytics_events
GROUP BY app_version
ORDER BY ultimo DESC;
-- atteso: la versione recente in formato "1.0.0+1" (version+build), non "1.0.0"

-- E4. Nessuno ha firmato eventi a nome d'altri (controllo storico).
SELECT count(*) AS eventi_con_utente, count(DISTINCT user_id) AS utenti_distinti
FROM public.analytics_events
WHERE user_id IS NOT NULL;
-- di riferimento: confrontalo con il numero di account registrati


-- ═══════════════════════════════════════════════════════════════════════════
-- F. Dopo la 015 — le tabelle del foglio sono chiuse
-- ═══════════════════════════════════════════════════════════════════════════

-- F1. Chi ha quali privilegi sulle due tabelle del monitoraggio.
SELECT table_name, grantee, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegi
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('analytics_events', 'activity_events')
  AND grantee IN ('anon', 'authenticated', 'service_role')
GROUP BY table_name, grantee
ORDER BY table_name, grantee;
-- atteso: analytics_events → anon: INSERT | authenticated: INSERT | service_role: tutto
--         activity_events  → anon e authenticated ASSENTI | service_role: tutto

-- F2. La scrittura funziona ancora — è il vero rischio della 015.
--     Esegui dopo aver aperto l'app e navigato due pagine del sito (vedi Z2).
SELECT 'analytics_events' AS tabella, count(*) AS righe_ultimi_5_min
FROM public.analytics_events WHERE created_at > now() - interval '5 minutes'
UNION ALL
SELECT 'activity_events', count(*)
FROM public.activity_events WHERE created_at > now() - interval '5 minutes';
-- atteso: entrambe > 0

-- F3. Il contatore "Download da sito" può funzionare (serve il CHECK allargato).
SELECT pg_get_constraintdef(oid) AS vincolo_event_type
FROM pg_constraint
WHERE conrelid = 'public.activity_events'::regclass
  AND conname = 'activity_events_event_type_check';
-- atteso: l'elenco include 'download_click'


-- ═══════════════════════════════════════════════════════════════════════════
-- G. La fotografia generale — da fare comunque prima del lancio
-- ═══════════════════════════════════════════════════════════════════════════

-- G1. Tabelle con la RLS SPENTA: ognuna è leggibile per intero da chi ha un GRANT.
SELECT c.relname AS tabella_senza_rls
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
ORDER BY 1;
-- l'istantanea vecchia in docs/database/struttura_rls.json dava spente
-- `pagamenti` e `biglietti`: fidati di questa query, non di quel file

-- G2. Chi può LEGGERE cosa con la chiave pubblica.
SELECT table_name, grantee
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'authenticated')
  AND privilege_type = 'SELECT'
ORDER BY table_name, grantee;
-- ogni riga è una tabella interrogabile da un utente dell'app: se non ha una
-- policy che la restringe, la legge tutta

-- G3. Tabelle con la RLS accesa ma SENZA nessuna policy: sembrano protette,
--     e lo sono, ma solo per assenza — la prima policy scritta male le apre.
SELECT c.relname AS rls_accesa_senza_policy
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
  AND NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = 'public' AND p.tablename = c.relname)
ORDER BY 1;

-- G4. Dati di test ancora in produzione (pulizia pre-lancio).
SELECT 'eventi passati' AS cosa, count(*) FROM public.eventi WHERE inizio_evento < now() - interval '60 days'
UNION ALL
SELECT 'prenotazioni di test', count(*) FROM public.prenotazioni WHERE created_at < now() - interval '60 days';
-- da confrontare con docs/database/seed_cleanup.sql


-- ═══════════════════════════════════════════════════════════════════════════
-- Z. Quello che NON si verifica da qui
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Z1. Eventi pre-login (E2): disinstalla l'app, riaprila e NON fare accesso.
--     Poi torna qui ed esegui E2.
--
-- Z2. Scrittura ancora viva (F2): apri l'app e naviga due pagine del sito
--     prima di eseguire F2.
--
-- Z3. Il buco della vista è chiuso — è LA verifica della 012.
--     Con il JWT di un utente NORMALE dell'app (non un gestore):
--       curl "$SUPABASE_URL/rest/v1/v_prenotazioni_dashboard?select=nome,cognome&limit=5" \
--            -H "apikey: <publishable>" -H "Authorization: Bearer <jwt utente app>"
--     -> prima: le anagrafiche di tutti i clienti di tutti i locali.
--        adesso: solo i suoi biglietti, o [].
--
-- Z4. Le tabelle del monitoraggio non si leggono con la chiave pubblica:
--       curl "$SUPABASE_URL/rest/v1/analytics_events?select=*&limit=1" -H "apikey: <publishable>"
--       curl "$SUPABASE_URL/rest/v1/activity_events?select=*&limit=1"  -H "apikey: <publishable>"
--     -> permission denied su entrambe, anche aggiungendo un JWT valido.
--
-- Z5. Un utente non può firmare eventi a nome d'altri (014). Con il JWT di A:
--       curl -X POST "$SUPABASE_URL/rest/v1/analytics_events" \
--         -H "apikey: <publishable>" -H "Authorization: Bearer <jwt di A>" \
--         -H "Content-Type: application/json" \
--         -d '{"event_name":"prova","user_id":"<id di B>"}'
--     -> 403, new row violates row-level security policy
--
-- Z6. Il gestionale non si è svuotato (012). Accedi al sito con un account
--     GESTORE e poi con uno STAFF: /dashboard, /storico e lo scanner devono
--     funzionare per entrambi. È qui che si scopre se la 007 non era applicata.
--
-- Z7. Il check-in si scrive davvero: scansiona un biglietto, poi
--       SELECT checked_in_at FROM public.prenotazioni_prevendite WHERE id = '<biglietto>';
--     -> valorizzato. Se resta NULL manca la policy gestori_update_checkin.
--
-- Z8. La chiave del foglio. Nessuna query può dirti chi ha accesso in modifica
--     al Google Sheet: chi ce l'ha può aprire l'Apps Script e leggere la
--     service_role key, che scavalca tutto quanto sopra. Controllalo a mano.
-- =============================================================================
