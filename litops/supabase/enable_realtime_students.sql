-- Enable Realtime broadcast for student_master and yearly_imports tables
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor > New Query > Run)

-- 1. Add tables to supabase_realtime publication
DO $$
DECLARE
  tables text[] := ARRAY['student_master', 'yearly_imports'];
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

-- 2. Set replica identity to full to capture all row modification details in realtime streams
ALTER TABLE student_master REPLICA IDENTITY FULL;
ALTER TABLE yearly_imports REPLICA IDENTITY FULL;

-- 3. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
