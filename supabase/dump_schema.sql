-- =============================================================================
-- OnList Club — Rigenerazione dei dump di schema
--
-- Da eseguire nell'SQL editor di ppbxhedbludoqnagzugm DOPO aver applicato tutte
-- le migration in sospeso (011→015, più migration_eta_minima.sql e i tre file
-- del repo del sito).
--
-- PERCHÉ RIFARLI
-- Gli artefatti in docs/database/ raccontano un database di aprile: la tabella
-- `eventi` che descrivono si ferma a `fine_evento`, senza `eta_minima`,
-- `dress_code`, `sound_system`, `parcheggio`, `lineup`, `limite_entrata` — tutte
-- colonne che l'app legge ogni giorno. Un file di schema più vecchio del
-- database non è documentazione: è una risposta sbagliata data con sicurezza,
-- ed è il motivo per cui "esiste eta_minima_anni?" non si è potuto risolvere
-- leggendo il repo.
--
-- COME
-- Ogni query restituisce UNA riga con UNA colonna JSON. Nell'SQL editor:
-- esegui, scarica il risultato, salvalo con il nome indicato. Sono file di
-- documentazione, non vanno eseguiti da nessuno.
-- =============================================================================


-- ═══════════════════════════════════════════════════════════════════════════
-- 1 → docs/database/colonne.json
--     Ogni tabella con le sue colonne, tipo, nullabilità e default.
--     È il file che risponde a "esiste la colonna X?".
-- ═══════════════════════════════════════════════════════════════════════════
SELECT jsonb_pretty(jsonb_agg(t ORDER BY t->>'tabella'))
FROM (
  SELECT jsonb_build_object(
    'tabella', c.relname,
    'rls_attiva', c.relrowsecurity,
    'colonne', (
      SELECT jsonb_agg(jsonb_build_object(
        'nome', a.attname,
        'tipo', format_type(a.atttypid, a.atttypmod),
        'nullable', NOT a.attnotnull,
        'default', pg_get_expr(d.adbin, d.adrelid)
      ) ORDER BY a.attnum)
      FROM pg_attribute a
      LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
      WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    )
  ) AS t
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
) s;


-- ═══════════════════════════════════════════════════════════════════════════
-- 2 → docs/database/struttura_rls.json  (sostituisce quello vecchio)
--     RLS accesa/spenta E le policy per esteso. Il file attuale ha solo il
--     flag, per 18 tabelle su un numero maggiore: non elenca nemmeno
--     prenotazioni_prevendite, prevendite, scan_logs, analytics_events.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT jsonb_pretty(jsonb_agg(t ORDER BY t->>'tabella'))
FROM (
  SELECT jsonb_build_object(
    'tabella', c.relname,
    'rls_attiva', c.relrowsecurity,
    'policy', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'nome', p.policyname,
        'comando', p.cmd,
        'ruoli', p.roles,
        'using', p.qual,
        'with_check', p.with_check
      ) ORDER BY p.policyname)
      FROM pg_policies p
      WHERE p.schemaname = 'public' AND p.tablename = c.relname
    ), '[]'::jsonb)
  ) AS t
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
) s;


-- ═══════════════════════════════════════════════════════════════════════════
-- 3 → docs/database/grants.json   (nuovo, e il più importante dei sei)
--     Chi può fare cosa con la chiave pubblica. La RLS filtra le righe, ma è
--     il GRANT a decidere se la richiesta arriva. Ogni riga con `anon` o
--     `authenticated` in SELECT è una tabella che un utente dell'app può
--     interrogare: se non ha una policy che la restringe, la legge tutta.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT jsonb_pretty(jsonb_agg(t ORDER BY t->>'tabella', t->>'ruolo'))
FROM (
  SELECT jsonb_build_object(
    'tabella', table_name,
    'ruolo', grantee,
    'privilegi', jsonb_agg(DISTINCT privilege_type ORDER BY privilege_type)
  ) AS t
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public'
    AND grantee IN ('anon', 'authenticated', 'service_role')
  GROUP BY table_name, grantee
) s;


-- ═══════════════════════════════════════════════════════════════════════════
-- 4 → docs/database/struttura_funzioni.json  (sostituisce quello vecchio)
--     Funzioni e RPC, con security definer/invoker e il search_path.
--     `security_definer = true` significa "gira con i permessi del
--     proprietario": ognuna va guardata due volte.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT jsonb_pretty(jsonb_agg(t ORDER BY t->>'nome'))
FROM (
  SELECT jsonb_build_object(
    'nome', p.proname,
    'argomenti', pg_get_function_identity_arguments(p.oid),
    'ritorna', pg_get_function_result(p.oid),
    'security_definer', p.prosecdef,
    'search_path', array_to_json(p.proconfig),
    'linguaggio', l.lanname
  ) AS t
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname = 'public'
) s;


-- ═══════════════════════════════════════════════════════════════════════════
-- 5 → docs/database/viste.json   (nuovo)
--     Le view con il flag security_invoker. Una view senza quel flag legge le
--     tabelle con i permessi del proprietario e scavalca la RLS di chi
--     interroga: è esattamente com'era v_prenotazioni_dashboard prima
--     della 012, ed è un controllo che conviene rifare a ogni giro.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT jsonb_pretty(jsonb_agg(t ORDER BY t->>'vista'))
FROM (
  SELECT jsonb_build_object(
    'vista', c.relname,
    'security_invoker', COALESCE(
      (SELECT true FROM unnest(c.reloptions) o WHERE o = 'security_invoker=true'),
      false
    ),
    'definizione', pg_get_viewdef(c.oid, true)
  ) AS t
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'v'
) s;


-- ═══════════════════════════════════════════════════════════════════════════
-- 6 → docs/database/trigger.json   (nuovo)
--     I trigger sono la metà delle regole di questo database e non compaiono
--     in nessuno dei file attuali: lo stock delle prevendite, il sold out, il
--     limite d'età, l'email di scansione. Se uno manca, la regola non esiste
--     e nessuno se ne accorge finché non serve.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT jsonb_pretty(jsonb_agg(t ORDER BY t->>'tabella', t->>'trigger'))
FROM (
  SELECT jsonb_build_object(
    'tabella', c.relname,
    'trigger', tg.tgname,
    'attivo', tg.tgenabled = 'O',
    'funzione', p.proname,
    'definizione', pg_get_triggerdef(tg.oid)
  ) AS t
  FROM pg_trigger tg
  JOIN pg_class c ON c.oid = tg.tgrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_proc p ON p.oid = tg.tgfoid
  WHERE n.nspname = 'public' AND NOT tg.tgisinternal
) s;


-- =============================================================================
-- Gli altri due artefatti, che NON si fanno da qui
-- =============================================================================
--
-- docs/SCHEMA_UFFICIALE_DB.sql — il DDL completo. Serve la CLI, con la password
-- del database (Dashboard → Settings → Database):
--
--     supabase link --project-ref ppbxhedbludoqnagzugm
--     supabase db dump --schema public -f docs/SCHEMA_UFFICIALE_DB.sql
--
-- Sito_Web_OnListClub_MVP/src/integrations/supabase/types.ts — i tipi
-- TypeScript del gestionale. In testa dicono "automatically generated, do not
-- edit", ma nel repo non c'è niente che li generi, e infatti `checked_in_at` e
-- `checkin_effettuati` ce li ho aggiunti a mano. Il comando giusto è:
--
--     supabase gen types typescript --project-id ppbxhedbludoqnagzugm \
--       > src/integrations/supabase/types.ts
--
-- Rigenerarli dopo le migration sostituisce le mie aggiunte con quelle vere e
-- toglie di mezzo la possibilità che i tipi e il database divergano di nuovo.
-- Dopo, ricontrolla che il sito compili: npx tsc --noEmit
-- =============================================================================
