-- ============================================================================
-- LitOps RLS Alignment and Role Synchronization Fix
-- Run this script in your Supabase Dashboard > SQL Editor to resolve RLS policy violations.
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


-- ============================================================================
-- STUDENT_MASTER RLS Alignment (All roles except junior_wing can insert/update)
-- ============================================================================
ALTER TABLE student_master ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view students" ON student_master;
DROP POLICY IF EXISTS "Admins and DB managers can insert students" ON student_master;
DROP POLICY IF EXISTS "Admins and DB managers can update students" ON student_master;
DROP POLICY IF EXISTS "Authorized roles can insert students" ON student_master;
DROP POLICY IF EXISTS "Authorized roles can update students" ON student_master;
DROP POLICY IF EXISTS "President can delete students" ON student_master;

CREATE POLICY "Authenticated users can view students" ON student_master FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authorized roles can insert students" ON student_master FOR INSERT TO authenticated WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role != 'junior_wing'::user_role AND is_active = true
  )
);

CREATE POLICY "Authorized roles can update students" ON student_master FOR UPDATE TO authenticated USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role != 'junior_wing'::user_role AND is_active = true
  )
);

CREATE POLICY "President and super admin can delete students" ON student_master FOR DELETE TO authenticated USING (
  is_super_admin() OR is_role('student_president')
);


-- ============================================================================
-- REGISTRATIONS RLS Alignment (All roles except junior_wing can create/update)
-- ============================================================================
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view registrations" ON registrations;
DROP POLICY IF EXISTS "Authorized roles can create registrations" ON registrations;
DROP POLICY IF EXISTS "Authorized roles can update registrations" ON registrations;

CREATE POLICY "Authenticated users can view registrations" ON registrations FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authorized roles can create registrations" ON registrations FOR INSERT TO authenticated WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role != 'junior_wing'::user_role AND is_active = true
  )
);

CREATE POLICY "Authorized roles can update registrations" ON registrations FOR UPDATE TO authenticated USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role != 'junior_wing'::user_role AND is_active = true
  )
);


-- ============================================================================
-- TEAMS & TEAM_MEMBERS RLS Alignment (All roles except junior_wing can manage teams)
-- ============================================================================
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view teams" ON teams;
DROP POLICY IF EXISTS "Authorized roles can manage teams" ON teams;
DROP POLICY IF EXISTS "Authenticated users can view team members" ON team_members;
DROP POLICY IF EXISTS "Authorized roles can manage team members" ON team_members;

CREATE POLICY "Authenticated users can view teams" ON teams FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage teams" ON teams FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role != 'junior_wing'::user_role AND is_active = true
  )
);

CREATE POLICY "Authenticated users can view team members" ON team_members FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage team members" ON team_members FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role != 'junior_wing'::user_role AND is_active = true
  )
);


-- ============================================================================
-- WAITING LIST RLS Alignment (All roles except junior_wing can manage waiting list)
-- ============================================================================
ALTER TABLE waiting_list ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view waiting list" ON waiting_list;
DROP POLICY IF EXISTS "Authorized roles can manage waiting list" ON waiting_list;

CREATE POLICY "Authenticated users can view waiting list" ON waiting_list FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage waiting list" ON waiting_list FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role != 'junior_wing'::user_role AND is_active = true
  )
);


-- ============================================================================
-- ATTENDANCE RLS Alignment (All authenticated users can mark attendance)
-- ============================================================================
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view attendance" ON attendance;
DROP POLICY IF EXISTS "Authorized roles can mark attendance" ON attendance;
DROP POLICY IF EXISTS "Authorized roles can update attendance" ON attendance;

CREATE POLICY "Authenticated users can view attendance" ON attendance FOR SELECT TO authenticated USING (true);

CREATE POLICY "All authenticated users can mark attendance" ON attendance FOR INSERT TO authenticated WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND is_active = true
  )
);

CREATE POLICY "All authenticated users can update attendance" ON attendance FOR UPDATE TO authenticated USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND is_active = true
  )
);


-- Verification output
SELECT 'Database RLS policies aligned successfully!' as status;
