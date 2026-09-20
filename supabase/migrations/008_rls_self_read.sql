-- =============================================================================
-- OnList Club — Fix RLS Staff Self-Read e Gestori (008)
--
-- Applica questa migration sul progetto Supabase dell'app: ppbxhedbludoqnagzugm
--
-- Problema: la policy RLS su public.staff usa `club_id = my_club_id()`.
-- Se uno staff member ha club_id NULL (o se my_club_id() fallisce perché
-- non trova ancora il record), non riesce a leggere il proprio record nel
-- login flow. Stessa cosa per i gestori nella tabella gestori.
--
-- Soluzione:
--   1. Aggiunge policy self-read per staff (ogni membro legge il proprio record)
--   2. Aggiunge policy self-read per gestori (ogni gestore legge il proprio record)
-- =============================================================================

-- 1. Policy self-read per la tabella STAFF
-- Permette a ogni membro dello staff di leggere il proprio record (necessario
-- per il login flow che usa .from("staff").eq("id", userId))
DROP POLICY IF EXISTS staff_self_read ON public.staff;
CREATE POLICY staff_self_read ON public.staff
  FOR SELECT TO authenticated
  USING (id = auth.uid());

-- 2. Policy self-read per la tabella GESTORI
-- Permette a ogni gestore di leggere il proprio record (necessario per il
-- login flow che usa .from("gestori").eq("id", userId))
DROP POLICY IF EXISTS gestori_self_read ON public.gestori;
CREATE POLICY gestori_self_read ON public.gestori
  FOR SELECT TO authenticated
  USING (id = auth.uid());

COMMENT ON POLICY staff_self_read ON public.staff IS
  'Permette a ogni membro dello staff di leggere il proprio record (necessario per login).';
COMMENT ON POLICY gestori_self_read ON public.gestori IS
  'Permette a ogni gestore di leggere il proprio record (necessario per login).';
