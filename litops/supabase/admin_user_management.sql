-- ============================================================================
-- LitOps Admin User Management & Security Migration
-- Run this in Supabase SQL Editor
-- ============================================================================

-- 1. Extend profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS branch TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS department TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_permissions TEXT[] DEFAULT '{}';

-- 2. Create password request enum type if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'password_request_status') THEN
    CREATE TYPE public.password_request_status AS ENUM ('pending', 'approved', 'rejected', 'completed');
  END IF;
END $$;

-- 3. Create password change requests table
CREATE TABLE IF NOT EXISTS public.password_change_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status public.password_request_status NOT NULL DEFAULT 'pending',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES public.profiles(id),
  completed_at TIMESTAMPTZ,
  UNIQUE(user_id, status)
);

-- 4. Enable RLS on password_change_requests
ALTER TABLE public.password_change_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own requests" ON public.password_change_requests;
CREATE POLICY "Users can view own requests" ON public.password_change_requests
  FOR SELECT TO authenticated USING (auth.uid() = user_id OR is_super_admin());

DROP POLICY IF EXISTS "Users can insert own pending requests" ON public.password_change_requests;
CREATE POLICY "Users can insert own pending requests" ON public.password_change_requests
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND status = 'pending');

DROP POLICY IF EXISTS "Super admins can manage requests" ON public.password_change_requests;
CREATE POLICY "Super admins can manage requests" ON public.password_change_requests
  FOR ALL TO authenticated USING (is_super_admin());

-- 5. Create helper function for profile restrictions trigger
CREATE OR REPLACE FUNCTION public.enforce_profile_update_restrictions()
RETURNS TRIGGER AS $$
BEGIN
  -- If it's a super admin, they can change anything
  IF public.is_super_admin() THEN
    RETURN NEW;
  END IF;

  -- If it's a normal user updating their own profile
  IF auth.uid() = NEW.id THEN
    -- They are only allowed to change photo_url
    IF NEW.full_name <> OLD.full_name OR
       NEW.email <> OLD.email OR
       NEW.role <> OLD.role OR
       COALESCE(NEW.usn, '') <> COALESCE(OLD.usn, '') OR
       COALESCE(NEW.branch, '') <> COALESCE(OLD.branch, '') OR
       COALESCE(NEW.department, '') <> COALESCE(OLD.department, '') OR
       COALESCE(NEW.year, 0) <> COALESCE(OLD.year, 0) OR
       NEW.is_active <> OLD.is_active OR
       COALESCE(NEW.phone, '') <> COALESCE(OLD.phone, '') OR
       COALESCE(NEW.custom_permissions, '{}'::text[]) <> COALESCE(OLD.custom_permissions, '{}'::text[])
    THEN
      RAISE EXCEPTION 'Restricted columns (Name, Email, USN, Branch, Year, Role, Phone, Department, Permissions) can only be modified by the Super Admin.';
    END IF;
    RETURN NEW;
  END IF;

  -- Otherwise, disallow update
  RAISE EXCEPTION 'Unauthorized profile update.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind trigger to profiles table
DROP TRIGGER IF EXISTS trg_enforce_profile_update_restrictions ON public.profiles;
CREATE TRIGGER trg_enforce_profile_update_restrictions
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.enforce_profile_update_restrictions();

-- 6. RPC: create_new_user
CREATE OR REPLACE FUNCTION public.create_new_user(
  p_email TEXT,
  p_password TEXT,
  p_full_name TEXT,
  p_usn TEXT,
  p_branch TEXT,
  p_year INT,
  p_role TEXT,
  p_phone TEXT,
  p_photo_url TEXT
)
RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
  v_encrypted_password TEXT;
BEGIN
  -- 1. Check if caller is super admin
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only Super Admins can create new users.';
  END IF;

  -- 2. Check if email already exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RAISE EXCEPTION 'A user with this email already exists.';
  END IF;

  -- 3. Hash the password using blowfish (standard for Supabase Auth)
  v_encrypted_password := crypt(p_password, gen_salt('bf', 10));
  v_user_id := uuid_generate_v4();

  -- 4. Insert into auth.users
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    aud,
    role,
    created_at,
    updated_at
  )
  VALUES (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    p_email,
    v_encrypted_password,
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object('full_name', p_full_name),
    'authenticated',
    'authenticated',
    now(),
    now()
  );

  -- 5. Insert into auth.identities
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  )
  VALUES (
    v_user_id::text,
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', p_email, 'email_verified', true),
    'email',
    now(),
    now(),
    now()
  );

  -- 6. Insert into profiles
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    role,
    phone,
    photo_url,
    usn,
    branch,
    year,
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    v_user_id,
    p_email,
    p_full_name,
    p_role::user_role,
    p_phone,
    p_photo_url,
    p_usn,
    p_branch,
    p_year,
    true,
    now(),
    now()
  );

  -- 7. Insert into member_assignments
  INSERT INTO public.member_assignments (
    user_id,
    role,
    status,
    assigned_by,
    assigned_at,
    created_at,
    updated_at
  )
  VALUES (
    v_user_id,
    p_role::user_role,
    'active'::member_status,
    auth.uid(),
    now(),
    now(),
    now()
  );

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: admin_update_user_details
CREATE OR REPLACE FUNCTION public.admin_update_user_details(
  p_user_id UUID,
  p_email TEXT,
  p_full_name TEXT,
  p_usn TEXT,
  p_branch TEXT,
  p_year INT,
  p_role TEXT,
  p_phone TEXT,
  p_photo_url TEXT,
  p_is_active BOOLEAN,
  p_custom_permissions TEXT[]
)
RETURNS VOID AS $$
BEGIN
  -- 1. Check if caller is super admin
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only Super Admins can update user details.';
  END IF;

  -- 2. Update auth.users email and metadata
  UPDATE auth.users
  SET email = p_email,
      raw_user_meta_data = jsonb_build_object('full_name', p_full_name),
      updated_at = now()
  WHERE id = p_user_id;

  -- 3. Update auth.identities email
  UPDATE auth.identities
  SET identity_data = jsonb_build_object('sub', p_user_id::text, 'email', p_email, 'email_verified', true),
      updated_at = now()
  WHERE user_id = p_user_id;

  -- 4. Update public.profiles
  UPDATE public.profiles
  SET email = p_email,
      full_name = p_full_name,
      usn = p_usn,
      branch = p_branch,
      year = p_year,
      role = p_role::user_role,
      phone = p_phone,
      photo_url = p_photo_url,
      is_active = p_is_active,
      custom_permissions = p_custom_permissions,
      updated_at = now()
  WHERE id = p_user_id;

  -- 5. Update member_assignments status and role
  UPDATE public.member_assignments
  SET role = p_role::user_role,
      status = CASE WHEN p_is_active THEN 'active'::member_status ELSE 'suspended'::member_status END,
      updated_at = now()
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RPC: admin_reset_user_password
CREATE OR REPLACE FUNCTION public.admin_reset_user_password(
  p_user_id UUID,
  p_new_password TEXT
)
RETURNS VOID AS $$
BEGIN
  -- 1. Check if caller is super admin
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only Super Admins can reset user passwords.';
  END IF;

  -- 2. Update auth.users password
  UPDATE auth.users
  SET encrypted_password = crypt(p_new_password, gen_salt('bf', 10)),
      updated_at = now()
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. RPC: admin_delete_user
CREATE OR REPLACE FUNCTION public.admin_delete_user(
  p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
  -- 1. Check if caller is super admin
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only Super Admins can delete users.';
  END IF;

  -- 2. Delete from auth.users (will cascade delete profiles & member_assignments)
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. RPC: change_own_password
CREATE OR REPLACE FUNCTION public.change_own_password(p_new_password TEXT)
RETURNS VOID AS $$
DECLARE
  v_req_id UUID;
BEGIN
  -- 1. Check if there is an approved password change request
  SELECT id INTO v_req_id
  FROM public.password_change_requests
  WHERE user_id = auth.uid() AND status = 'approved'
  LIMIT 1;

  IF v_req_id IS NULL THEN
    RAISE EXCEPTION 'Password change request not approved by Super Admin.';
  END IF;

  -- 2. Update auth.users password
  UPDATE auth.users
  SET encrypted_password = crypt(p_new_password, gen_salt('bf', 10)),
      updated_at = now()
  WHERE id = auth.uid();

  -- 3. Mark request as completed
  UPDATE public.password_change_requests
  SET status = 'completed',
      completed_at = now()
  WHERE id = v_req_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
