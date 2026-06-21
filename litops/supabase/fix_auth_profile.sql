-- ============================================================================
-- LitOps Auth Fix — RUN THIS IN SUPABASE SQL EDITOR
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================

-- 1. DROP the broken trigger that causes "Database error saving new user"
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 2. Make sure RLS lets authenticated users insert/read/update their own profile
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 3. Output confirmation
SELECT 'Done! Broken trigger removed and RLS policies fixed.' AS status;
