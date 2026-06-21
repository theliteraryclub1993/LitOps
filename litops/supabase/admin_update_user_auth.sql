-- ============================================================================
-- LitOps: Admin Update User Auth Credentials RPC Function
-- RUN THIS IN SUPABASE SQL EDITOR
-- ============================================================================
-- This function allows the Super Admin to update a user's email and password.
-- Since auth.users is protected, this function runs with SECURITY DEFINER.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin_update_user_auth(
  p_user_id UUID,
  p_email TEXT DEFAULT NULL,
  p_password TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- 1. Verify the caller is a super_admin and active
  SELECT role::TEXT INTO caller_role
  FROM profiles
  WHERE id = auth.uid() AND is_active = true;

  IF caller_role IS NULL OR caller_role != 'super_admin' THEN
    RAISE EXCEPTION 'Permission denied: only super_admin can update user credentials.';
  END IF;

  -- 2. Update email in auth.users if provided
  IF p_email IS NOT NULL AND p_email != '' THEN
    -- Check for duplicate emails
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email AND id != p_user_id) THEN
      RAISE EXCEPTION 'Email is already in use by another user.';
    END IF;

    UPDATE auth.users
    SET email = p_email,
        email_change_sent_at = NULL,
        email_confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Update email in auth.identities (required for login to work under new email)
    UPDATE auth.identities
    SET identity_data = jsonb_build_object('sub', p_user_id::TEXT, 'email', p_email),
        updated_at = NOW()
    WHERE user_id = p_user_id AND provider = 'email';
  END IF;

  -- 3. Update password in auth.users if provided
  IF p_password IS NOT NULL AND p_password != '' THEN
    IF length(p_password) < 6 THEN
      RAISE EXCEPTION 'Password must be at least 6 characters.';
    END IF;

    UPDATE auth.users
    SET encrypted_password = crypt(p_password, gen_salt('bf')),
        updated_at = NOW()
    WHERE id = p_user_id;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verification output
SELECT 'admin_update_user_auth RPC function created successfully!' AS status;
