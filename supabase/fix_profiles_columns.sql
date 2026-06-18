-- ============================================================
-- FIX: Add missing columns to profiles table
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add 'year' column (which year of college: 1, 2, 3, or 4)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS year INTEGER CHECK (year BETWEEN 1 AND 4);

-- 2. Add 'usn' column (university seat number)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS usn TEXT;

-- 3. Fix the UPDATE RLS policy to explicitly allow updating all fields
--    including 'role', 'year', 'usn', 'date_of_birth', etc.
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 4. Also ensure admins can update any profile (for role sync from admin panel)
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;
CREATE POLICY "Admins can update any profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ============================================================
-- VERIFY: Run this SELECT to check columns exist
-- ============================================================
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'profiles'
-- ORDER BY ordinal_position;
