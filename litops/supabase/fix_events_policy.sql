-- ============================================================================
-- LitOps Event Creation and Member Assignment RLS Fix
-- Run this script in your Supabase SQL Editor to apply the correct permissions
-- ============================================================================

-- 1. Ensure the user_role enum contains 'super_admin'
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'super_admin';

-- 2. Define or update the helper functions
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

-- 3. Set the role of theliteraryclubmce@gmail.com to super_admin and make active
UPDATE profiles 
SET role = 'super_admin'::user_role, is_active = true 
WHERE email = 'theliteraryclubmce@gmail.com';

-- 4. Delete any previous member assignments for theliteraryclubmce@gmail.com
DELETE FROM member_assignments 
WHERE user_id IN (
  SELECT id FROM profiles WHERE email = 'theliteraryclubmce@gmail.com'
);

-- 5. Automatically promote theliteraryclubmce@gmail.com to super_admin on insert or update
CREATE OR REPLACE FUNCTION auto_promote_super_admin()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email = 'theliteraryclubmce@gmail.com' THEN
    NEW.role := 'super_admin'::user_role;
    NEW.is_active := true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auto_promote_super_admin ON profiles;
CREATE TRIGGER trg_auto_promote_super_admin
BEFORE INSERT OR UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION auto_promote_super_admin();

-- 6. Reconfigure EVENTS RLS Policies (ONLY super_admin can create/modify/delete)
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view events" ON events;
DROP POLICY IF EXISTS "Admins and event managers can create events" ON events;
DROP POLICY IF EXISTS "Admins and event managers can update events" ON events;
DROP POLICY IF EXISTS "Admins can delete events" ON events;
DROP POLICY IF EXISTS "Super admin can create events" ON events;
DROP POLICY IF EXISTS "Super admin can update events" ON events;
DROP POLICY IF EXISTS "Super admin can delete events" ON events;

CREATE POLICY "Authenticated users can view events" ON events FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can create events" ON events FOR INSERT TO authenticated WITH CHECK (is_super_admin());
CREATE POLICY "Super admin can update events" ON events FOR UPDATE TO authenticated USING (is_super_admin());
CREATE POLICY "Super admin can delete events" ON events FOR DELETE TO authenticated USING (is_super_admin());

-- 7. Reconfigure EVENT_ASSIGNMENTS RLS Policies (Allow super admin, admins, event managers, assistant coordinators, and junior wings to assign members)
ALTER TABLE event_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view assignments" ON event_assignments;
DROP POLICY IF EXISTS "Admins can manage assignments" ON event_assignments;
DROP POLICY IF EXISTS "Authorized roles can manage assignments" ON event_assignments;

CREATE POLICY "Authenticated users can view assignments" ON event_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage assignments" ON event_assignments FOR ALL TO authenticated USING (
  is_super_admin() OR 
  is_admin() OR 
  is_role('event_manager') OR 
  is_role('assistant_coordinator') OR 
  is_role('junior_wing')
);

-- 8. Reconfigure STUDENT_MASTER RLS Policies (Allow event managers and assistant coordinators to insert/update manually)
ALTER TABLE student_master ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins and DB managers can insert students" ON student_master;
DROP POLICY IF EXISTS "Admins and DB managers can update students" ON student_master;
DROP POLICY IF EXISTS "Authorized roles can insert students" ON student_master;
DROP POLICY IF EXISTS "Authorized roles can update students" ON student_master;

CREATE POLICY "Authorized roles can insert students" ON student_master FOR INSERT TO authenticated WITH CHECK (
  is_admin() OR 
  is_role('database_manager') OR 
  is_role('event_manager') OR 
  is_role('assistant_coordinator')
);

CREATE POLICY "Authorized roles can update students" ON student_master FOR UPDATE TO authenticated USING (
  is_admin() OR 
  is_role('database_manager') OR 
  is_role('event_manager') OR 
  is_role('assistant_coordinator')
);

-- Output verification status
SELECT 
  p.email, 
  p.role as profile_role, 
  (SELECT COUNT(*) FROM member_assignments ma WHERE ma.user_id = p.id) as assignments_count
FROM profiles p 
WHERE p.email = 'theliteraryclubmce@gmail.com';
