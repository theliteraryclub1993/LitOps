-- ============================================================================
-- LitOps RLS and Role Override Fix
-- Run this in the Supabase SQL Editor to resolve database errors when creating events or students
-- ============================================================================

-- 1. Redefine is_role to automatically grant all roles to super_admin
CREATE OR REPLACE FUNCTION is_role(required_role user_role)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
      AND (role = required_role OR role = 'super_admin') 
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Allow authenticated users to insert their own profile during sign up
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- 3. Automatically promote theliteraryclubmce@gmail.com to super_admin when their profile is inserted/updated
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

-- 4. Set the role of any existing user with the superadmin email to super_admin
UPDATE profiles 
SET role = 'super_admin'::user_role, is_active = true 
WHERE email = 'theliteraryclubmce@gmail.com';

-- 5. Set RLS for students and events to make sure is_admin / is_super_admin are integrated
ALTER TABLE student_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Output confirmation
SELECT 'RLS and Role policies applied successfully! Super Admin will now automatically bypass RLS.' as status;
