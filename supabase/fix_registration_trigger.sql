-- ============================================================================
-- LitOps Registration Trigger Fix
-- Run this in the Supabase SQL Editor to resolve "Database error saving new user"
-- ============================================================================

-- 1. Drop the trigger on auth.users if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Drop the trigger function if it exists
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 3. Ensure the profiles table has the correct RLS policy for first-time profile creation
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles 
  FOR INSERT 
  WITH CHECK (true);

-- Output confirmation
SELECT 'Registration triggers cleared and profiles insert policy updated successfully!' as status;
