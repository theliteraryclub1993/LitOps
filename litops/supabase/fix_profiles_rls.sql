-- ============================================================================
-- LitOps Profiles RLS Fix — RUN THIS IN SUPABASE SQL EDITOR
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================

-- 1. Drop the policies on profiles table that cause infinite recursion
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;

-- 2. Create a clean select policy that allows all authenticated users to read profiles
-- This resolves the infinite recursion policy loop (profiles select policy -> is_admin() -> profiles select)
CREATE POLICY "Authenticated users can view profiles" ON profiles
  FOR SELECT TO authenticated USING (true);

-- 3. Output confirmation
SELECT 'Done! Profiles RLS policy updated to prevent infinite recursion.' AS status;
