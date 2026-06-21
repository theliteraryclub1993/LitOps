-- ============================================================================
-- LitOps: Admin Create User RPC Function (FIXED!)
-- RUN THIS IN SUPABASE SQL EDITOR TO OVERWRITE THE EXISTING FUNCTION
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================
-- This fixed version:
--  1. Correctly inserts into auth.identities
--  2. Sets instance_id from an existing working user
--  3. Sets proper email confirmation
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
  working_instance_id UUID;
  encrypted_pw TEXT;
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

  -- 4. Get a working instance_id from an existing user (the super admin!)
  SELECT instance_id INTO working_instance_id
  FROM auth.users
  WHERE email = 'theliteraryclubmce@gmail.com'
  LIMIT 1;

  -- Fallback: if that email doesn't exist, get the first user's instance_id
  IF working_instance_id IS NULL THEN
    SELECT instance_id INTO working_instance_id
    FROM auth.users
    WHERE instance_id IS NOT NULL
    LIMIT 1;
  END IF;

  -- 5. Generate new user UUID
  new_user_id := uuid_generate_v4();

  -- 6. Encrypt password using Supabase's crypt() function
  encrypted_pw := crypt(p_password, gen_salt('bf'));

  -- 7. Insert into auth.users
  INSERT INTO auth.users (
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    instance_id,
    confirmation_sent_at,
    confirmation_token,
    recovery_sent_at,
    recovery_token,
    email_change_sent_at,
    email_change_token_new,
    email_change,
    email_change_confirm_status,
    banned_until,
    reauthentication_sent_at,
    reauthentication_token,
    is_super_admin,
    deleted_at
  ) VALUES (
    new_user_id,
    'authenticated',
    'authenticated',
    p_email,
    encrypted_pw,
    NOW(),  -- Auto-confirm email
    '{"provider":"email","providers":["email"]}'::jsonb,
    format('{"full_name":"%s"}', p_full_name)::jsonb,
    NOW(),
    NOW(),
    working_instance_id,
    NOW(),
    '',
    NULL,
    '',
    NULL,
    '',
    '',
    0,
    NULL,
    NULL,
    '',
    false,
    NULL
  );

  -- 8. Insert into auth.identities (CRITICAL for login!)
  INSERT INTO auth.identities (
    id,
    user_id,
    provider_id,
    provider,
    identity_data,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    new_user_id,
    new_user_id,
    p_email,
    'email',
    format('{"sub":"%s","email":"%s","email_verified":true}', new_user_id, p_email)::jsonb,
    NOW(),
    NOW(),
    NOW()
  );

  -- 9. Insert into profiles
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
SELECT '✅ admin_create_user function updated successfully!' AS status;
