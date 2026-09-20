-- =============================================================================
-- 002 — Fix bug in public.get_gestore_by_codice
-- =============================================================================
--
-- La function in 001_struttura_iniziale.sql referenziava `public.clubs` che
-- NON esiste (la tabella è `public.locali`). La function viene quindi
-- ricreata corretta.
--
-- Sicurezza: aggiunto `SET search_path TO 'public', 'pg_temp'` per coerenza
-- con le altre function SECURITY DEFINER del DB (best practice contro attacchi
-- via search_path injection).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_gestore_by_codice(p_codice text)
RETURNS TABLE(email text, club_nome text)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  return query
    select g.email, l.nome
    from public.gestori g
    join public.locali l on l.id = g.club_id
    where g.codice = p_codice
      and g.attivo = true
    limit 1;
end;
$function$;
