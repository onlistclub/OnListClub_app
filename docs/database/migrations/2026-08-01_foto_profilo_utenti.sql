-- ============================================================================
-- Foto profilo utente (schermata Account, design NUOVO)
-- ============================================================================
-- DA APPLICARE A MANO sul Dashboard Supabase (SQL Editor): l'MCP del progetto
-- è in sola lettura.
--
-- Finché questa migration non è applicata, l'app funziona lo stesso:
-- `getUserProfile()` ricade sulla select senza `foto_url` e il tap sulla foto
-- mostra l'errore di upload invece di salvare.
-- ============================================================================

-- 1. Colonna con l'URL pubblico della foto profilo.
ALTER TABLE public.utenti
  ADD COLUMN IF NOT EXISTS foto_url text;

COMMENT ON COLUMN public.utenti.foto_url IS
  'URL pubblico della foto profilo (bucket storage `avatars`), con query di '
  'cache-busting ?v=<timestamp>. NULL = nessuna foto caricata.';

-- 2. Bucket pubblico per gli avatar.
--    Pubblico perché l'URL viene mostrato direttamente nell'app senza firma.
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 3. Policy Storage: ogni utente gestisce SOLO la propria cartella
--    (il path caricato dall'app è `<auth.uid()>/avatar.<ext>`), lettura
--    pubblica per poter mostrare la foto.
DROP POLICY IF EXISTS "Avatar leggibili da tutti" ON storage.objects;
CREATE POLICY "Avatar leggibili da tutti"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Ognuno carica il proprio avatar" ON storage.objects;
CREATE POLICY "Ognuno carica il proprio avatar"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Ognuno aggiorna il proprio avatar" ON storage.objects;
CREATE POLICY "Ognuno aggiorna il proprio avatar"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Ognuno elimina il proprio avatar" ON storage.objects;
CREATE POLICY "Ognuno elimina il proprio avatar"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- NB: `utenti` ha già la policy UPDATE sul proprio profilo usata da
-- updateProfile(), quindi il salvataggio di `foto_url` non richiede altro.
