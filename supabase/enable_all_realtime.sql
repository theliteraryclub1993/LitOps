-- Enable Realtime for all required tables
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New Query > Run)

DO $$
DECLARE
  tables text[] := ARRAY['events', 'results', 'event_points', 'registrations', 'attendance', 'notifications'];
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY tables
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', table_name);
      RAISE NOTICE 'Added % to supabase_realtime publication', table_name;
    EXCEPTION
      WHEN duplicate_object THEN
        RAISE NOTICE '% is already in supabase_realtime publication', table_name;
    END;
  END LOOP;
END $$;

-- Set replica identity to full for all tables to capture all changes
ALTER TABLE events REPLICA IDENTITY FULL;
ALTER TABLE results REPLICA IDENTITY FULL;
ALTER TABLE event_points REPLICA IDENTITY FULL;
ALTER TABLE registrations REPLICA IDENTITY FULL;
ALTER TABLE attendance REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- Verify setup
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime';
