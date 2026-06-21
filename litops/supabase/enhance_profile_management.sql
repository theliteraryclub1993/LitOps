-- ============================================================================
-- LitOps: Enhanced Profile Management SQL Migration
-- Run this in Supabase SQL Editor
-- ============================================================================

-- 1. Add missing columns to profiles table
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS profile_image TEXT,
  ADD COLUMN IF NOT EXISTS dob DATE,
  ADD COLUMN IF NOT EXISTS academic_year INTEGER,
  ADD COLUMN IF NOT EXISTS account_status VARCHAR(50) DEFAULT 'active';

-- 2. Populate new columns from existing data
UPDATE public.profiles
SET profile_image = photo_url,
    dob = date_of_birth,
    academic_year = year,
    account_status = CASE WHEN is_active = true THEN 'active' ELSE 'disabled' END
WHERE profile_image IS NULL;

-- 3. Create Bidirectional Column Sync Trigger Function
CREATE OR REPLACE FUNCTION public.sync_profile_columns()
RETURNS TRIGGER AS $$
BEGIN
  -- Sync photo_url and profile_image
  IF TG_OP = 'INSERT' THEN
    IF NEW.profile_image IS NOT NULL THEN
      NEW.photo_url := NEW.profile_image;
    ELSIF NEW.photo_url IS NOT NULL THEN
      NEW.profile_image := NEW.photo_url;
    END IF;
  ELSE
    IF NEW.profile_image IS DISTINCT FROM OLD.profile_image THEN
      NEW.photo_url := NEW.profile_image;
    ELSIF NEW.photo_url IS DISTINCT FROM OLD.photo_url THEN
      NEW.profile_image := NEW.photo_url;
    END IF;
  END IF;

  -- Sync date_of_birth and dob
  IF TG_OP = 'INSERT' THEN
    IF NEW.dob IS NOT NULL THEN
      NEW.date_of_birth := NEW.dob;
    ELSIF NEW.date_of_birth IS NOT NULL THEN
      NEW.dob := NEW.date_of_birth;
    END IF;
  ELSE
    IF NEW.dob IS DISTINCT FROM OLD.dob THEN
      NEW.date_of_birth := NEW.dob;
    ELSIF NEW.date_of_birth IS DISTINCT FROM OLD.date_of_birth THEN
      NEW.dob := NEW.date_of_birth;
    END IF;
  END IF;

  -- Sync year and academic_year
  IF TG_OP = 'INSERT' THEN
    IF NEW.academic_year IS NOT NULL THEN
      NEW.year := NEW.academic_year;
    ELSIF NEW.year IS NOT NULL THEN
      NEW.academic_year := NEW.year;
    END IF;
  ELSE
    IF NEW.academic_year IS DISTINCT FROM OLD.academic_year THEN
      NEW.year := NEW.academic_year;
    ELSIF NEW.year IS DISTINCT FROM OLD.year THEN
      NEW.academic_year := NEW.year;
    END IF;
  END IF;

  -- Sync is_active and account_status
  IF TG_OP = 'INSERT' THEN
    IF NEW.account_status IS NOT NULL THEN
      IF NEW.account_status = 'active' THEN
        NEW.is_active := true;
      ELSE
        NEW.is_active := false;
      END IF;
    ELSIF NEW.is_active IS NOT NULL THEN
      IF NEW.is_active THEN
        NEW.account_status := 'active';
      ELSE
        NEW.account_status := 'disabled';
      END IF;
    END IF;
  ELSE
    IF NEW.account_status IS DISTINCT FROM OLD.account_status THEN
      IF NEW.account_status = 'active' THEN
        NEW.is_active := true;
      ELSE
        NEW.is_active := false;
      END IF;
    ELSIF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      IF NEW.is_active THEN
        NEW.account_status := 'active';
      ELSE
        NEW.account_status := 'disabled';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_profile_columns ON public.profiles;
CREATE TRIGGER trg_sync_profile_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_columns();

-- 4. Recreate Profile Update Restrictions Trigger Function
CREATE OR REPLACE FUNCTION public.enforce_profile_update_restrictions()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow INSERT operations completely
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- Allow SUPER ADMIN to update anything
  IF EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  ) THEN
    RETURN NEW;
  END IF;

  -- Allow normal users updating their own profile
  IF auth.uid() = NEW.id THEN
    -- Check that NO restricted fields are changed
    IF (
      NEW.email = OLD.email AND
      NEW.role = OLD.role AND
      COALESCE(NEW.branch, '') = COALESCE(OLD.branch, '') AND
      COALESCE(NEW.department, '') = COALESCE(OLD.department, '') AND
      COALESCE(NEW.year, 0) = COALESCE(OLD.year, 0) AND
      COALESCE(NEW.academic_year, 0) = COALESCE(OLD.academic_year, 0) AND
      NEW.is_active = OLD.is_active AND
      COALESCE(NEW.account_status, '') = COALESCE(OLD.account_status, '') AND
      COALESCE(NEW.custom_permissions, '{}'::text[]) = COALESCE(OLD.custom_permissions, '{}'::text[]) AND
      NEW.profile_completed = OLD.profile_completed AND
      NEW.profile_status = OLD.profile_status AND
      COALESCE(NEW.rejection_reason, '') = COALESCE(OLD.rejection_reason, '')
    ) THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Restricted profile columns (Email, USN, Year, Role, Status, Permissions) can only be modified by the Super Admin.';
  END IF;

  -- Otherwise block
  RAISE EXCEPTION 'Unauthorized profile update.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
DROP TRIGGER IF EXISTS trg_enforce_profile_update_restrictions ON public.profiles;
CREATE TRIGGER trg_enforce_profile_update_restrictions
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profile_update_restrictions();

-- 5. Storage policies for profile_pictures bucket (allow super_admin override)
-- Ensure bucket exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile_pictures', 'profile_pictures', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Drop old storage policies
DROP POLICY IF EXISTS "Public Read Access for Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Users Upload own Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Users Update own Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Users Delete own Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Super Admins or Owners can Upload Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Super Admins or Owners can Update Profile Pictures" ON storage.objects;
DROP POLICY IF EXISTS "Super Admins or Owners can Delete Profile Pictures" ON storage.objects;

-- Create public read access policy
CREATE POLICY "Public Read Access for Profile Pictures"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile_pictures');

-- Create upload policy
CREATE POLICY "Super Admins or Owners can Upload Profile Pictures"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile_pictures'
  AND (
    (name LIKE auth.uid()::text || '%')
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  )
);

-- Create update policy
CREATE POLICY "Super Admins or Owners can Update Profile Pictures"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile_pictures'
  AND (
    (name LIKE auth.uid()::text || '%')
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  )
)
WITH CHECK (
  bucket_id = 'profile_pictures'
  AND (
    (name LIKE auth.uid()::text || '%')
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  )
);

-- Create delete policy
CREATE POLICY "Super Admins or Owners can Delete Profile Pictures"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile_pictures'
  AND (
    (name LIKE auth.uid()::text || '%')
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  )
);

-- 6. RLS UPDATE policy on profiles table (ensure users can update themselves and admins can update all)
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  ))
  WITH CHECK (auth.uid() = id OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'super_admin'
  ));

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
