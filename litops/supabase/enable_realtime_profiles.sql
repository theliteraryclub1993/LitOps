-- Enable Realtime for profiles table
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New Query > Run)

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
    RAISE NOTICE 'Added profiles to supabase_realtime publication';
  EXCEPTION
    WHEN duplicate_object THEN
      RAISE NOTICE 'profiles is already in supabase_realtime publication';
  END;
END $$;

-- Set replica identity to full to capture all column updates in realtime broadcasts
ALTER TABLE profiles REPLICA IDENTITY FULL;
