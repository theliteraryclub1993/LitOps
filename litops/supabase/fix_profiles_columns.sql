-- ============================================================
-- FIX: Add missing columns and setup triggers/policies for profiles
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > Run)
-- ============================================================

-- 1. Add all missing columns to the profiles table
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS year INTEGER CHECK (year BETWEEN 1 AND 4),
  ADD COLUMN IF NOT EXISTS usn TEXT,
  ADD COLUMN IF NOT EXISTS branch TEXT,
  ADD COLUMN IF NOT EXISTS department TEXT,
  ADD COLUMN IF NOT EXISTS custom_permissions TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS profile_status VARCHAR(50) NOT NULL DEFAULT 'pending_review',
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2. Update existing profiles (make sure admins/presidents/etc. are marked as completed & approved)
UPDATE public.profiles
SET profile_completed = true,
    profile_status = 'approved'
WHERE role != 'junior_wing' OR email = 'theliteraryclubmce@gmail.com';

-- 3. Fix UPDATE RLS policies to allow profile updates
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
CREATE POLICY "Admins can update any profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (role = 'super_admin' OR role = 'student_president' OR role = 'student_vice_president' OR role = 'joint_secretary' OR role = 'event_director')
    )
  );

-- 4. Recreate/Simplify trigger function to allow first-time profile setup
DROP TRIGGER IF EXISTS trg_enforce_profile_update_restrictions ON public.profiles;

CREATE OR REPLACE FUNCTION public.enforce_profile_update_restrictions()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow INSERT operations completely (for profile creation on sign-up)
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
    -- If the profile wasn't completed before, allow setting full_name, profile_completed, year, usn, branch, department, profile_status
    IF (OLD.profile_completed IS NULL OR OLD.profile_completed = false) THEN
      RETURN NEW;
    END IF;

    -- For completed profiles, only allow changing photo_url, phone, or date_of_birth
    -- Check that NO restricted fields are changed
    IF (
      NEW.full_name = OLD.full_name AND
      NEW.email = OLD.email AND
      NEW.role = OLD.role AND
      COALESCE(NEW.usn, '') = COALESCE(OLD.usn, '') AND
      COALESCE(NEW.branch, '') = COALESCE(OLD.branch, '') AND
      COALESCE(NEW.department, '') = COALESCE(OLD.department, '') AND
      COALESCE(NEW.year, 0) = COALESCE(OLD.year, 0) AND
      NEW.is_active = OLD.is_active AND
      COALESCE(NEW.custom_permissions, '{}'::text[]) = COALESCE(OLD.custom_permissions, '{}'::text[]) AND
      NEW.profile_completed = OLD.profile_completed AND
      NEW.profile_status = OLD.profile_status AND
      COALESCE(NEW.rejection_reason, '') = COALESCE(OLD.rejection_reason, '')
    ) THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Restricted profile columns can only be modified by the Super Admin.';
  END IF;

  -- Otherwise block
  RAISE EXCEPTION 'Unauthorized profile update.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_enforce_profile_update_restrictions
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profile_update_restrictions();

-- 5. Force reload PostgREST schema cache to make columns visible immediately
NOTIFY pgrst, 'reload schema';

