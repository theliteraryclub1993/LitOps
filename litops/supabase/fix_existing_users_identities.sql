-- ============================================================================
-- LitOps: Fix Existing Users and Identities — RUN THIS IN SUPABASE SQL EDITOR
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================
-- This script fixes existing users created with the old admin_create_user RPC:
--   1. Corrects the 'id' in auth.identities to match the user's UUID
--   2. Aligns the 'instance_id' in auth.users to match the active Super Admin
-- ============================================================================

-- 1. Correct any identities created with random UUIDs
UPDATE auth.identities
SET id = user_id
WHERE provider = 'email' AND id != user_id;

-- 2. Align instance_ids with the instance_id of the Super Admin (which works)
UPDATE auth.users
SET instance_id = (
  SELECT instance_id 
  FROM auth.users 
  WHERE email = 'theliteraryclubmce@gmail.com' 
  LIMIT 1
)
WHERE instance_id = '00000000-0000-0000-0000-000000000000'::UUID;

-- Verification output
SELECT 'Done! Existing users and identities fixed successfully.' AS status;
