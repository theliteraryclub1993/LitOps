-- ============================================================================
-- LitOps: Admin Create User RPC Function (ULTIMATE FIX!)
-- RUN THIS IN SUPABASE SQL EDITOR TO OVERWRITE THE EXISTING FUNCTION
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================
-- This version uses Supabase's OFFICIAL auth.create_user() function which:
--  1. Correctly hashes passwords with Supabase's algorithm
--  2. Automatically creates auth.identities
--  3. Sets correct instance_id and all auth fields perfectly
--  4. Auto-confirms email
-- ============================================================================

CREATE OR REPLACE FUNCTION admin_create_user(
  p_email TEXT,
  p_password TEXT,
  p_full_name TEXT,
  p_role TEXT DEFAULT 'junior_wing',
  p_phone TEXT DEFAULT NULL,
  p_year INTEGER DEFAULT NULL,
  p_usn TEXT DEFAULT NULL,
  p_date_of_birth TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  caller_role TEXT;
  new_user_id UUID;
BEGIN
  -- 1. Verify the caller is a super_admin
  SELECT role::TEXT INTO caller_role
  FROM profiles
  WHERE id = auth.uid() AND is_active = true;

  IF caller_role IS NULL OR caller_role != 'super_admin' THEN
    RAISE EXCEPTION 'Permission denied: only super_admin can create user accounts.';
  END IF;

  -- 2. Validate required fields
  IF p_email IS NULL OR p_email = '' THEN
    RAISE EXCEPTION 'Email is required.';
  END IF;
  IF p_password IS NULL OR length(p_password) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters.';
  END IF;
  IF p_full_name IS NULL OR p_full_name = '' THEN
    RAISE EXCEPTION 'Full name is required.';
  END IF;

  -- 3. Check if email already exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RAISE EXCEPTION 'A user with this email already exists.';
  END IF;

  -- 4. Use SUPABASE'S OFFICIAL auth.create_user() function! (This is the KEY FIX!)
  new_user_id := (auth.create_user(
    email => p_email,
    password => p_password,
    email_confirm => true,  -- Auto-confirm the email
    user_metadata => json_build_object('full_name', p_full_name)
  )).id;

  -- 5. Now insert into our public.profiles table
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    role,
    phone,
    year,
    usn,
    date_of_birth,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    new_user_id,
    p_email,
    p_full_name,
    p_role::user_role,
    p_phone,
    p_year,
    p_usn,
    CASE WHEN p_date_of_birth IS NOT NULL THEN p_date_of_birth::DATE ELSE NULL END,
    true,
    NOW(),
    NOW()
  );

  RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verify the function was created
SELECT '✅ admin_create_user function updated to use auth.create_user()!' AS status;

-- Also, let's create a helper to check existing users' auth status
SELECT
  au.id,
  au.email,
  au.email_confirmed_at,
  (p.id IS NOT NULL) AS has_profile,
  p.role,
  p.is_active
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
ORDER BY au.created_at DESC;
