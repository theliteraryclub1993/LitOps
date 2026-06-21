-- ============================================================================
-- LitOps Schema Fix - Add Category Column to Events Table
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New Query > Run)
-- ============================================================================

-- 1. Create the event_category enum type if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_category') THEN
    CREATE TYPE event_category AS ENUM ('balwaan', 'buddhimaan', 'darpan', 'kalakruthi');
  END IF;
END $$;

-- 2. Add the category column to the events table
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS category event_category;

-- 3. Update existing rows to have a default category if any exist
UPDATE public.events SET category = 'balwaan'::event_category WHERE category IS NULL;

-- 4. Set the column to NOT NULL if needed (since it's required by the app)
ALTER TABLE public.events ALTER COLUMN category SET NOT NULL;

-- 5. Force PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';

-- Output confirmation
SELECT 'Category column and enum verified/added successfully to events table!' as status;
