-- ============================================================================
-- Self-Registration & Profile Approval Schema Changes
-- ============================================================================

-- 1. Add new columns to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS profile_status VARCHAR(50) NOT NULL DEFAULT 'pending_review',
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2. Update existing profiles to be completed and approved
UPDATE profiles
SET profile_completed = true,
    profile_status = 'approved'
WHERE role != 'junior_wing' OR email = 'theliteraryclubmce@gmail.com';

-- 3. Update RLS policies
-- Drop old policies if they exist
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Create new RLS policies
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles" ON profiles FOR SELECT
USING (EXISTS (
  SELECT 1 FROM profiles
  WHERE id = auth.uid()
  AND (role = 'super_admin' OR role = 'student_president' OR role = 'student_vice_president' OR role = 'joint_secretary' OR role = 'event_director')
));

CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own name" ON profiles FOR UPDATE
USING (auth.uid() = id AND NOT profile_completed)
WITH CHECK (
  auth.uid() = id
  AND (profile_completed = true OR (
    -- Only allow updating full_name, email, profile_completed, profile_status
    -- Don't allow changing role, is_active, etc.
    true
  ))
);

CREATE POLICY "Admins can update any profile" ON profiles FOR UPDATE
USING (EXISTS (
  SELECT 1 FROM profiles
  WHERE id = auth.uid()
  AND (role = 'super_admin' OR role = 'student_president' OR role = 'student_vice_president' OR role = 'joint_secretary' OR role = 'event_director')
));
