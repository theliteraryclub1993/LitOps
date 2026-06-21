-- ============================================================================
-- COMPLETE SEARCH SETUP FOR LITOPS
-- ============================================================================

-- 1. Enable pg_trgm extension (required for fuzzy search)
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. Create global_search RPC function if not exists
CREATE OR REPLACE FUNCTION global_search(search_query TEXT, max_results INTEGER DEFAULT 20)
RETURNS TABLE (
  result_type TEXT,
  result_id UUID,
  primary_text TEXT,
  secondary_text TEXT,
  similarity_score REAL
) AS $$
BEGIN
  RETURN QUERY
  -- Student name search
  SELECT
    'student'::TEXT as result_type,
    sm.id as result_id,
    sm.name as primary_text,
    (sm.usn || ' • ' || sm.branch) as secondary_text,
    similarity(sm.name, search_query) as similarity_score
  FROM student_master sm
  WHERE sm.name % search_query OR sm.usn % search_query OR sm.name ILIKE '%' || search_query || '%' OR sm.usn ILIKE '%' || search_query || '%'

  UNION ALL

  -- Event name search
  SELECT
    'event'::TEXT,
    e.id,
    e.title,
    (e.category::TEXT || ' • ' || COALESCE(e.venue, 'TBD')),
    similarity(e.title, search_query)
  FROM events e
  WHERE e.title % search_query OR e.title ILIKE '%' || search_query || '%'

  UNION ALL

  -- Team name search (if teams table exists)
  SELECT
    'team'::TEXT,
    t.id,
    t.team_name,
    'Team',
    similarity(t.team_name, search_query)
  FROM teams t
  WHERE t.team_name % search_query OR t.team_name ILIKE '%' || search_query || '%'

  UNION ALL

  -- Member search
  SELECT
    'member'::TEXT,
    p.id,
    p.full_name,
    (p.email || ' • ' || p.role::TEXT),
    similarity(p.full_name, search_query)
  FROM profiles p
  WHERE p.full_name % search_query OR p.email ILIKE '%' || search_query || '%'

  ORDER BY similarity_score DESC
  LIMIT max_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create trigram indexes for better search performance
CREATE INDEX IF NOT EXISTS idx_student_master_name_trgm ON student_master USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_student_master_usn_trgm ON student_master USING gin (usn gin_trgm_ops);

-- 4. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- SEARCH IS NOW READY TO USE!
-- ============================================================================
