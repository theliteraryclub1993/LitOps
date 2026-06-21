-- ============================================================================
-- LitOps: Add branch and department columns to profiles table
-- RUN THIS IN SUPABASE SQL EDITOR
-- ============================================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS branch TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS department TEXT;

-- Verification query:
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'profiles';
