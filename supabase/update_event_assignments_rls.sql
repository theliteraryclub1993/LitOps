-- ============================================================================
-- LitOps Event Assignments RLS Update — RUN THIS IN SUPABASE SQL EDITOR
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================

-- 1. Create a function to check if the current user has access to manage event assignments.
-- Authorized users are: Super Admin, Event Managers (event_manager, event_manager_co_editorial), and all 4th year members.
CREATE OR REPLACE FUNCTION can_manage_event_assignments()
RETURNS BOOLEAN AS $$
DECLARE
  v_role user_role;
  v_year INTEGER;
BEGIN
  -- Get the current authenticated user's role and year from profiles
  SELECT role, year INTO v_role, v_year 
  FROM profiles 
  WHERE id = auth.uid() AND is_active = true;
  
  RETURN v_role = 'super_admin'::user_role 
      OR v_role = 'event_manager'::user_role 
      OR v_role = 'event_manager_co_editorial'::user_role 
      OR v_year = 4;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop existing manage policies
DROP POLICY IF EXISTS "Admins can manage assignments" ON event_assignments;
DROP POLICY IF EXISTS "Authorized roles can manage assignments" ON event_assignments;

-- 3. Create updated policy
CREATE POLICY "Authorized roles can manage assignments" ON event_assignments
  FOR ALL TO authenticated USING (
    can_manage_event_assignments()
  );

-- 4. Remove too restrictive unique constraints on user_id if they exist
-- The schema table only has UNIQUE(event_id, user_id, assignment_role), which already allows one member to be assigned to more than 1 event.
-- We run this to ensure no other unique constraints got added.
ALTER TABLE event_assignments DROP CONSTRAINT IF EXISTS event_assignments_user_id_key;
ALTER TABLE event_assignments DROP CONSTRAINT IF EXISTS event_assignments_event_id_user_id_key;

-- 5. Confirmation message
SELECT 'Done! Event Assignments RLS policy and constraints updated successfully.' AS status;
