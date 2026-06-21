-- Simplified fix for profile trigger to allow first-time setup
-- Replace the entire function and trigger

-- Step 1: Drop old trigger first
DROP TRIGGER IF EXISTS trg_enforce_profile_update_restrictions ON public.profiles;

-- Step 2: Create new, simpler function
CREATE OR REPLACE FUNCTION public.enforce_profile_update_restrictions()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow INSERT operations completely
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- Allow SUPER ADMIN to do anything
  IF public.is_super_admin() THEN
    RETURN NEW;
  END IF;

  -- Allow users updating their own profile
  IF auth.uid() = NEW.id THEN
    -- If the profile wasn't completed before, allow setting full_name, profile_completed, and profile_status
    IF (OLD.profile_completed IS NULL OR OLD.profile_completed = false) THEN
      -- Allow these fields to change
      -- Also allow photo_url (existing behavior)
      RETURN NEW;
    END IF;

    -- For completed profiles, only allow photo_url changes
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
      COALESCE(NEW.phone, '') = COALESCE(OLD.phone, '') AND
      COALESCE(NEW.custom_permissions, '{}'::text[]) = COALESCE(OLD.custom_permissions, '{}'::text[]) AND
      NEW.profile_completed = OLD.profile_completed AND
      NEW.profile_status = OLD.profile_status AND
      COALESCE(NEW.rejection_reason, '') = COALESCE(OLD.rejection_reason, '')
    ) THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Restricted columns can only be modified by the Super Admin.';
  END IF;

  -- Otherwise block
  RAISE EXCEPTION 'Unauthorized profile update.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Recreate trigger
CREATE TRIGGER trg_enforce_profile_update_restrictions
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.enforce_profile_update_restrictions();
