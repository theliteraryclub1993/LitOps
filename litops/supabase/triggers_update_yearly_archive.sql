-- Trigger functions to auto-update active yearly_archive stats

-- Function to update all stats in active yearly_archive
CREATE OR REPLACE FUNCTION update_yearly_archive_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update active yearly_archive's all stats
  UPDATE yearly_archives
  SET total_events = (
    SELECT COUNT(*) FROM events
  ),
  total_registrations = (
    SELECT COUNT(*) FROM registrations WHERE is_cancelled = false
  ),
  total_participants = (
    SELECT COUNT(DISTINCT student_id) FROM registrations WHERE is_cancelled = false
  ),
  total_attendance = (
    SELECT COUNT(*) FROM attendance
  ),
  updated_at = NOW()
  WHERE is_active = true;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trg_update_yearly_archive_registrations ON registrations;
DROP TRIGGER IF EXISTS trg_update_yearly_archive_attendance ON attendance;
DROP TRIGGER IF EXISTS trg_update_yearly_archive_events ON events;

-- Create triggers for registrations
CREATE TRIGGER trg_update_yearly_archive_registrations
AFTER INSERT OR UPDATE OR DELETE ON registrations
FOR EACH STATEMENT EXECUTE FUNCTION update_yearly_archive_stats();

-- Create triggers for attendance
CREATE TRIGGER trg_update_yearly_archive_attendance
AFTER INSERT OR UPDATE OR DELETE ON attendance
FOR EACH STATEMENT EXECUTE FUNCTION update_yearly_archive_stats();

-- Create triggers for events
CREATE TRIGGER trg_update_yearly_archive_events
AFTER INSERT OR UPDATE OR DELETE ON events
FOR EACH STATEMENT EXECUTE FUNCTION update_yearly_archive_stats();

