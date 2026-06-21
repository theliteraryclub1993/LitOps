-- ============================================================================
-- LitOps: Delete Member Profile RPC Function
-- RUN THIS IN SUPABASE SQL EDITOR
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================
-- This function handles member profile deletion safely:
--   1. Validates the caller is a super_admin
--   2. Cleans up / nullifies foreign key references across all tables
--   3. Deletes the profile row (which cascades to member_assignments, etc.)
-- ============================================================================

CREATE OR REPLACE FUNCTION delete_member_profile(target_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- 1. Verify the caller is a super_admin
  SELECT role::TEXT INTO caller_role
  FROM profiles
  WHERE id = auth.uid() AND is_active = true;

  IF caller_role IS NULL OR caller_role != 'super_admin' THEN
    RAISE EXCEPTION 'Permission denied: only super_admin can delete member profiles.';
  END IF;

  -- 2. Prevent self-deletion
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot delete your own profile.';
  END IF;

  -- 3. Verify target profile exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = target_user_id) THEN
    RAISE EXCEPTION 'Profile not found for id: %', target_user_id;
  END IF;

  -- 4. Nullify nullable foreign key references (audit trail columns)
  UPDATE events SET created_by = auth.uid() WHERE created_by = target_user_id;
  UPDATE registrations SET registered_by = auth.uid() WHERE registered_by = target_user_id;
  UPDATE registrations SET cancelled_by = NULL WHERE cancelled_by = target_user_id;
  UPDATE teams SET registered_by = auth.uid() WHERE registered_by = target_user_id;
  UPDATE attendance SET marked_by = NULL WHERE marked_by = target_user_id;
  UPDATE round_scores SET scored_by = NULL WHERE scored_by = target_user_id;
  UPDATE results SET published_by = NULL WHERE published_by = target_user_id;
  UPDATE certificates SET issued_by = NULL WHERE issued_by = target_user_id;
  UPDATE appeals SET resolved_by = NULL WHERE resolved_by = target_user_id;
  UPDATE announcements SET created_by = auth.uid() WHERE created_by = target_user_id;
  UPDATE incidents SET reported_by = auth.uid() WHERE reported_by = target_user_id;
  UPDATE gallery SET uploaded_by = auth.uid() WHERE uploaded_by = target_user_id;
  UPDATE student_database_backups SET created_by = auth.uid() WHERE created_by = target_user_id;
  UPDATE database_import_history SET imported_by = auth.uid() WHERE imported_by = target_user_id;
  UPDATE yearly_archives SET created_by = NULL WHERE created_by = target_user_id;
  UPDATE yearly_imports SET imported_by = auth.uid() WHERE imported_by = target_user_id;
  UPDATE event_points SET allocated_by = auth.uid() WHERE allocated_by = target_user_id;
  UPDATE event_points SET approved_by = NULL WHERE approved_by = target_user_id;
  UPDATE event_schedules SET coordinator_id = NULL WHERE coordinator_id = target_user_id;
  UPDATE event_schedules SET created_by = auth.uid() WHERE created_by = target_user_id;
  UPDATE barcode_logs SET scanned_by = NULL WHERE scanned_by = target_user_id;

  -- 5. Delete rows from tables that have ON DELETE CASCADE or should be cleaned up
  DELETE FROM offline_sync_queue WHERE user_id = target_user_id;
  DELETE FROM member_assignments WHERE user_id = target_user_id;
  DELETE FROM event_assignments WHERE user_id = target_user_id;

  -- 6. Delete the user from auth.users (which cascades to profiles, auth.identities, etc.)
  DELETE FROM auth.users WHERE id = target_user_id;

  -- Fallback: If ON DELETE CASCADE is not configured on profiles, delete it explicitly
  DELETE FROM profiles WHERE id = target_user_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verification output
SELECT 'delete_member_profile RPC function created successfully!' AS status;
