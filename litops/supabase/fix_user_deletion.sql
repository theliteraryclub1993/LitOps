-- ============================================================================
-- LitOps: Fix User Deletion (Identities, Instance ID, and Cascades)
-- Run this in the Supabase SQL Editor
-- ============================================================================
-- This script fixes two key issues:
--   1. "Database error loading user" - occurs when users lack a corresponding
--      record in the auth.identities table (common for manually seeded users).
--   2. Foreign key restriction blocks - when deleting a profile, other tables
--      referencing profiles(id) without ON DELETE CASCADE block the deletion.
-- ============================================================================

-- STEP 1: Fix missing identities in auth.identities
INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  provider,
  identity_data,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT 
  id,                    -- id (pass UUID directly)
  id,                    -- user_id (pass UUID directly)
  email,                 -- provider_id (email address)
  'email',               -- provider
  json_build_object('sub', id::text, 'email', email, 'email_verified', true)::jsonb, -- identity_data
  COALESCE(last_sign_in_at, confirmed_at, created_at, NOW()), -- last_sign_in_at
  COALESCE(created_at, NOW()), -- created_at
  COALESCE(updated_at, NOW())  -- updated_at
FROM auth.users
WHERE id NOT IN (
  SELECT user_id FROM auth.identities WHERE provider = 'email'
)
ON CONFLICT DO NOTHING;

-- STEP 2: Make sure all existing identities are correctly mapped with matching IDs
UPDATE auth.identities
SET id = user_id
WHERE provider = 'email' AND id != user_id;

-- STEP 3: Align instance_ids in auth.users with a working instance_id (e.g. from the super admin)
UPDATE auth.users
SET instance_id = (
  SELECT instance_id 
  FROM auth.users 
  WHERE email = 'theliteraryclubmce@gmail.com' 
  LIMIT 1
)
WHERE instance_id IS NULL OR instance_id = '00000000-0000-0000-0000-000000000000'::UUID;

-- STEP 4: Create BEFORE DELETE trigger on public.profiles to clean up database references
CREATE OR REPLACE FUNCTION public.handle_profile_before_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_fallback_id UUID;
BEGIN
  -- 1. Find a fallback active user to attribute NOT NULL references to.
  -- We prefer an active super_admin, then an active admin/president, then any other active user.
  SELECT id INTO v_fallback_id
  FROM public.profiles
  WHERE id != OLD.id AND role = 'super_admin' AND is_active = true
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_fallback_id IS NULL THEN
    SELECT id INTO v_fallback_id
    FROM public.profiles
    WHERE id != OLD.id AND role IN ('super_admin', 'student_president') AND is_active = true
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  IF v_fallback_id IS NULL THEN
    SELECT id INTO v_fallback_id
    FROM public.profiles
    WHERE id != OLD.id AND is_active = true
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  IF v_fallback_id IS NULL THEN
    SELECT id INTO v_fallback_id
    FROM public.profiles
    WHERE id != OLD.id
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  -- 2. Clean up or cascade delete rows from tables that are tightly bound to the user
  DELETE FROM public.event_assignments WHERE user_id = OLD.id;
  DELETE FROM public.offline_sync_queue WHERE user_id = OLD.id;
  DELETE FROM public.search_history WHERE user_id = OLD.id;
  DELETE FROM public.member_assignments WHERE user_id = OLD.id;

  -- 3. Nullify nullable foreign key references
  UPDATE public.registrations SET cancelled_by = NULL WHERE cancelled_by = OLD.id;
  UPDATE public.attendance SET marked_by = NULL WHERE marked_by = OLD.id;
  UPDATE public.round_scores SET scored_by = NULL WHERE scored_by = OLD.id;
  UPDATE public.results SET published_by = NULL WHERE published_by = OLD.id;
  UPDATE public.certificates SET issued_by = NULL WHERE issued_by = OLD.id;
  UPDATE public.appeals SET resolved_by = NULL WHERE resolved_by = OLD.id;
  UPDATE public.yearly_archives SET created_by = NULL WHERE created_by = OLD.id;
  UPDATE public.event_points SET approved_by = NULL WHERE approved_by = OLD.id;
  UPDATE public.event_schedules SET coordinator_id = NULL WHERE coordinator_id = OLD.id;
  UPDATE public.barcode_logs SET scanned_by = NULL WHERE scanned_by = OLD.id;

  -- 4. Re-attribute NOT NULL references to the fallback user if one exists
  IF v_fallback_id IS NOT NULL THEN
    UPDATE public.events SET created_by = v_fallback_id WHERE created_by = OLD.id;
    UPDATE public.student_database_backups SET created_by = v_fallback_id WHERE created_by = OLD.id;
    UPDATE public.database_import_history SET imported_by = v_fallback_id WHERE imported_by = OLD.id;
    UPDATE public.event_assignments SET assigned_by = v_fallback_id WHERE assigned_by = OLD.id;
    UPDATE public.registrations SET registered_by = v_fallback_id WHERE registered_by = OLD.id;
    UPDATE public.teams SET registered_by = v_fallback_id WHERE registered_by = OLD.id;
    UPDATE public.announcements SET created_by = v_fallback_id WHERE created_by = OLD.id;
    UPDATE public.incidents SET reported_by = v_fallback_id WHERE reported_by = OLD.id;
    UPDATE public.gallery SET uploaded_by = v_fallback_id WHERE uploaded_by = OLD.id;
    UPDATE public.member_assignments SET assigned_by = v_fallback_id WHERE assigned_by = OLD.id;
    UPDATE public.yearly_imports SET imported_by = v_fallback_id WHERE imported_by = OLD.id;
    UPDATE public.event_points SET allocated_by = v_fallback_id WHERE allocated_by = OLD.id;
    UPDATE public.event_schedules SET created_by = v_fallback_id WHERE created_by = OLD.id;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger on public.profiles
DROP TRIGGER IF EXISTS trg_handle_profile_before_delete ON public.profiles;
CREATE TRIGGER trg_handle_profile_before_delete
  BEFORE DELETE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_profile_before_delete();

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
