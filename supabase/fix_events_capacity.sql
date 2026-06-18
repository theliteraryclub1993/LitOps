-- ============================================================================
-- LitOps Schema Fix - Add Capacity Column to Events Table
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New Query > Run)
-- ============================================================================

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS capacity INTEGER;

-- Output confirmation
SELECT 'Capacity column verified/added successfully to events table!' as status;
