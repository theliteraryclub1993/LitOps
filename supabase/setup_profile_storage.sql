-- ============================================================================
-- Supabase Storage Setup for Profile Pictures
-- Run this in the Supabase SQL Editor to initialize the bucket and RLS policies.
-- ============================================================================

-- 1. Create the profile_pictures bucket if it does not exist, and ensure it is public
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile_pictures', 'profile_pictures', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Drop existing policies if they exist to prevent conflicts
DROP POLICY IF EXISTS "Public Read Access for Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Users Upload own Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Users Update own Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Users Delete own Profile Pictures" ON storage.objects;

-- 3. Create SELECT policy (allows public viewing of profile pictures)
CREATE POLICY "Public Read Access for Profile Pictures"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile_pictures');

-- 4. Create INSERT policy (allows authenticated users to upload their own profile picture)
-- The filename must start with the user's auth ID (e.g. auth.uid()::text)
CREATE POLICY "Authenticated Users Upload own Profile Pictures"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile_pictures'
  AND (name LIKE auth.uid()::text || '%')
);

-- 5. Create UPDATE policy (allows authenticated users to update their own profile picture)
CREATE POLICY "Authenticated Users Update own Profile Pictures"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile_pictures'
  AND (name LIKE auth.uid()::text || '%')
)
WITH CHECK (
  bucket_id = 'profile_pictures'
  AND (name LIKE auth.uid()::text || '%')
);

-- 6. Create DELETE policy (allows authenticated users to delete their own profile picture)
CREATE POLICY "Authenticated Users Delete own Profile Pictures"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile_pictures'
  AND (name LIKE auth.uid()::text || '%')
);
