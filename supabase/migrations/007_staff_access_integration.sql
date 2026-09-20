-- =============================================================================
-- OnList Club — Integrazione Accesso Staff e Separazione Ruoli (007)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
--
-- Modifiche:
--   1. Permette a public.staff.club_id di essere NULL all'inizio (come per i gestori)
--   2. Collega public.staff.id ad auth.users.id tramite FK
--   3. Aggiorna la funzione my_club_id() per controllare sia gestori sia staff
--   4. Aggiorna il trigger handle_new_gestore() per smistare gli utenti:
--      - role = 'gestore' -> inserito in public.gestori (ruolo = 'admin')
--      - role = 'staff'   -> inserito in public.staff (ruolo = 'staff')
-- =============================================================================

-- 1. Rendi club_id opzionale nella tabella staff
ALTER TABLE public.staff ALTER COLUMN club_id DROP NOT NULL;

-- 2. Collega la chiave primaria di staff ad auth.users (se non già presente)
ALTER TABLE public.staff DROP CONSTRAINT IF EXISTS staff_id_fkey;
ALTER TABLE public.staff
  ADD CONSTRAINT staff_id_fkey FOREIGN KEY (id)
  REFERENCES auth.users(id) ON DELETE CASCADE;

-- 3. Aggiorna my_club_id() per supportare RLS sia per gestori sia per staff
CREATE OR REPLACE FUNCTION public.my_club_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_club_id uuid;
BEGIN
  -- Controlla nei gestori (Manager)
  SELECT club_id INTO v_club_id
  FROM public.gestori
  WHERE id = auth.uid() AND attivo = true
  LIMIT 1;
  
  IF v_club_id IS NOT NULL THEN
    RETURN v_club_id;
  END IF;

  -- Controlla nello staff (Staff)
  SELECT club_id INTO v_club_id
  FROM public.staff
  WHERE id = auth.uid() AND attivo = true
  LIMIT 1;

  RETURN v_club_id;
END;
$function$;

COMMENT ON FUNCTION public.my_club_id() IS
  'Restituisce il club_id dell''utente loggato (cercando in gestori o staff). Usata per le policy RLS.';

-- 4. Aggiorna la funzione del trigger per smistare le registrazioni in base a metadata->>'role'
CREATE OR REPLACE FUNCTION public.handle_new_gestore()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- A. Registrazione come GESTORE / MANAGER
  IF (new.raw_user_meta_data->>'role') = 'gestore' THEN
    INSERT INTO public.gestori (id, club_id, codice, nome, ruolo, email, attivo)
    VALUES (
      new.id,
      NULLIF(new.raw_user_meta_data->>'club_id', '')::uuid,
      coalesce(new.raw_user_meta_data->>'codice', substr(new.id::text, 1, 8)),
      new.raw_user_meta_data->>'nome',
      'admin', -- Manager ha ruolo admin al momento
      new.email,
      true
    );
  -- B. Registrazione come STAFF
  ELSIF (new.raw_user_meta_data->>'role') = 'staff' THEN
    INSERT INTO public.staff (id, club_id, nome, ruolo, telefono, email, stato, attivo)
    VALUES (
      new.id,
      NULLIF(new.raw_user_meta_data->>'club_id', '')::uuid,
      coalesce(new.raw_user_meta_data->>'nome', 'Membro Staff'),
      'staff', -- Staff ha ruolo staff
      new.raw_user_meta_data->>'telefono',
      new.email,
      'green',
      true
    );
  END IF;
  RETURN new;
END;
$function$;

COMMENT ON FUNCTION public.handle_new_gestore() IS
  'Trigger automatico che smista l''utente in gestori (se role=gestore) o in staff (se role=staff).';
