-- Cleanup event_points table - optional, run if you have old data with student_id
-- Run this in Supabase SQL Editor

-- Optional: Set all existing student_id and team_id to null (in case you want to keep the points but remove individual tracking)
-- UPDATE event_points SET student_id = null, team_id = null WHERE student_id IS NOT NULL OR team_id IS NOT NULL;

-- Optional: Delete all existing event_points (if you want to start fresh and re-enter all results)
-- DELETE FROM event_points;

-- Verify cleanup
SELECT id, event_id, branch, student_id, team_id, points, reason, position
FROM event_points
ORDER BY created_at DESC;
