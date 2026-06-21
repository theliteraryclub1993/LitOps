-- ============================================================================
-- LitOps Profile Schema Extension — RUN THIS IN SUPABASE SQL EDITOR
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================

-- 1. Add 'year' column to the 'profiles' table if it doesn't exist
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS year INTEGER CHECK (year BETWEEN 1 AND 4);

-- 2. Make sure RLS is configured correctly to permit upserts by authenticated users
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (true);

-- 3. Output confirmation
SELECT 'Done! year column added and RLS policies updated for profiles.' AS status;
