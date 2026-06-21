-- ============================================================================
-- LitOps Login Issue: Comprehensive Debug Script
-- ============================================================================
-- Use this script in Supabase SQL Editor to diagnose login problems
-- ============================================================================

-- =============================================
-- 1. Check RLS Policies for profiles
-- =============================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'profiles';

-- =============================================
-- 2. List ALL profiles (including user id, email, full name, role)
-- =============================================
SELECT id, email, full_name, role, is_active, created_at
FROM profiles
ORDER BY created_at DESC;

-- =============================================
-- 3. List ALL auth.users (id, email, confirmed_at)
-- =============================================
SELECT id, email, email_confirmed_at, created_at
FROM auth.users
ORDER BY created_at DESC;

-- =============================================
-- 4. Check if auth.users has entries are linked to profiles
-- =============================================
SELECT 
  au.id AS auth_user_id,
  au.email AS auth_email,
  p.id AS profile_id,
  p.email AS profile_email,
  CASE WHEN p.id IS NULL THEN '❌ MISSING PROFILE' ELSE '✅ PROFILE OK' END AS status
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
ORDER BY au.created_at DESC;

-- =============================================
-- 5. Check user_fcm_tokens
-- =============================================
SELECT 
  uft.id, 
  uft.user_id, 
  p.full_name, 
  uft.device_type,
  uft.created_at,
  uft.updated_at
FROM user_fcm_tokens uft
LEFT JOIN profiles p ON uft.user_id = p.id
ORDER BY uft.created_at DESC;

-- =============================================
-- 6. Check pg_net extension is enabled
-- =============================================
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_net';

-- =============================================
-- 7. Check if triggers are active
-- =============================================
SELECT 
  event_object_table, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE event_object_table IN ('event_assignments', 'profiles', 'notifications');
ORDER BY event_object_table;
