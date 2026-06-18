-- ============================================================================
-- LitOps Results Creation and Modification RLS Fix
-- Run this script in your Supabase SQL Editor to apply the correct permissions
-- ============================================================================

-- Ensure the user_role enum contains 'event_manager_co_editorial'
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'event_manager_co_editorial';

-- Ensure the helper functions check user roles correctly (including super_admin and managers)
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin'::user_role AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_role(required_role user_role)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
      AND (role = required_role OR role = 'super_admin'::user_role) 
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
      AND (role = 'super_admin'::user_role OR role IN ('student_president', 'student_vice_president', 'joint_secretary', 'event_director')) 
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reconfigure RESULTS RLS Policies (Allow super_admin, admins, event_manager, event_manager_co_editorial)
ALTER TABLE results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view results" ON results;
DROP POLICY IF EXISTS "Admins can manage results" ON results;
DROP POLICY IF EXISTS "Authorized roles can manage results" ON results;

CREATE POLICY "Authenticated users can view results" ON results 
  FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Authorized roles can manage results" ON results 
  FOR ALL 
  TO authenticated 
  USING (
    is_super_admin() OR 
    is_admin() OR 
    is_role('event_manager') OR 
    is_role('event_manager_co_editorial')
  )
  WITH CHECK (
    is_super_admin() OR 
    is_admin() OR 
    is_role('event_manager') OR 
    is_role('event_manager_co_editorial')
  );

-- Also ensure event managers/admins can update the events table status when publishing results
DROP POLICY IF EXISTS "Super admin can update events" ON events;
DROP POLICY IF EXISTS "Authorized roles can update events" ON events;

CREATE POLICY "Authorized roles can update events" ON events 
  FOR UPDATE 
  TO authenticated 
  USING (
    is_super_admin() OR 
    is_admin() OR 
    is_role('event_manager') OR 
    is_role('event_manager_co_editorial') OR
    created_by = auth.uid()
  );

-- Verify results RLS setup
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename IN ('results', 'events');
