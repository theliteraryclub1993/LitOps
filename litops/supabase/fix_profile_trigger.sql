-- Fix profile restrictions trigger to allow first-time profile setup and new columns
CREATE OR REPLACE FUNCTION public.enforce_profile_update_restrictions()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow ALL INSERTS (for first-time profile creation)
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- If it's a super admin, they can change anything
  IF public.is_super_admin() THEN
    RETURN NEW;
  END IF;

  -- If it's a normal user updating their own profile
  IF auth.uid() = NEW.id THEN
    -- If profile is NOT completed yet, allow setting full_name, profile_completed, profile_status
    IF (OLD.profile_completed IS NULL OR OLD.profile_completed = false) THEN
      -- Only allow changes to: full_name, profile_completed, profile_status, photo_url
      IF (
        -- Allow setting full_name for first time
        (NEW.full_name <> OLD.full_name OR OLD.full_name IS NULL) OR
        -- Allow setting profile_completed
        NEW.profile_completed <> OLD.profile_completed OR
        -- Allow setting profile_status
        NEW.profile_status <> OLD.profile_status OR
        -- Allow updating photo_url (existing behavior)
        NEW.photo_url <> OLD.photo_url
      ) THEN
        -- Make sure NO OTHER fields are being changed!
        IF (
          NEW.email = OLD.email AND
          NEW.role = OLD.role AND
          COALESCE(NEW.usn, '') = COALESCE(OLD.usn, '') AND
          COALESCE(NEW.branch, '') = COALESCE(OLD.branch, '') AND
          COALESCE(NEW.department, '') = COALESCE(OLD.department, '') AND
          COALESCE(NEW.year, 0) = COALESCE(OLD.year, 0) AND
          NEW.is_active = OLD.is_active AND
          COALESCE(NEW.phone, '') = COALESCE(OLD.phone, '') AND
          COALESCE(NEW.custom_permissions, '{}'::text[]) = COALESCE(OLD.custom_permissions, '{}'::text[])
        ) THEN
          RETURN NEW;
        END IF;
      END IF;
    END IF;

    -- If profile IS completed, only allow photo_url
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

    RAISE EXCEPTION 'Restricted columns (Name, Email, USN, Branch, Year, Role, Phone, Department, Permissions) can only be modified by the Super Admin.';
  END IF;

  -- Otherwise, disallow update
  RAISE EXCEPTION 'Unauthorized profile update.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
