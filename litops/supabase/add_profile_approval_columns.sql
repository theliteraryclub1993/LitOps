-- Add profile approval columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS profile_status VARCHAR NOT NULL DEFAULT 'pending_review',
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Update existing profiles
UPDATE profiles 
SET profile_completed = true,
    profile_status = 'approved'
WHERE role != 'junior_wing' OR email = 'theliteraryclubmce@gmail.com';