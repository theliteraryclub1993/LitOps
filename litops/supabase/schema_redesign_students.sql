-- ============================================================================
-- LitOps: Student Database Redesign Migration
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New Query)
-- ============================================================================

-- 1. Create public.import_batches table for tracking import jobs
CREATE TABLE IF NOT EXISTS public.import_batches (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name       TEXT NOT NULL,
    academic_year   TEXT NOT NULL, -- e.g. "2026-27"
    uploaded_by     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    duplicate_mode  TEXT NOT NULL CHECK (duplicate_mode IN ('replace', 'skip')),
    status          TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    total_rows      INTEGER DEFAULT 0,
    processed_rows  INTEGER DEFAULT 0,
    inserted_count  INTEGER DEFAULT 0,
    updated_count   INTEGER DEFAULT 0,
    skipped_count   INTEGER DEFAULT 0,
    error_log       TEXT,
    created_at      TIMESTAMPTZ DEFAULT now(),
    completed_at    TIMESTAMPTZ
);

-- Enable Row Level Security (RLS) for import_batches
ALTER TABLE public.import_batches ENABLE ROW LEVEL SECURITY;

-- Select policies
DROP POLICY IF EXISTS "Authenticated users can select import batches" ON public.import_batches;
CREATE POLICY "Authenticated users can select import batches" ON public.import_batches
    FOR SELECT TO authenticated USING (true);

-- Manage policies (inserts/updates/deletes)
DROP POLICY IF EXISTS "Super admins can perform all actions on import batches" ON public.import_batches;
CREATE POLICY "Super admins can perform all actions on import batches" ON public.import_batches
    FOR ALL TO authenticated 
    USING (is_super_admin() OR is_role('student_president')) 
    WITH CHECK (is_super_admin() OR is_role('student_president'));


-- 2. Alter student_master to support section, academic year, semester, source, and batch reference
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS section TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS academic_year TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS semester INTEGER;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'fest_registration' CHECK (source IN ('historical_import', 'fest_registration', 'manual'));
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS import_batch_id UUID REFERENCES public.import_batches(id) ON DELETE SET NULL;


-- 3. Fix foreign key cascade deletes for teams captain reference
-- By default, it was restricting deletion. We change it to ON DELETE SET NULL
ALTER TABLE public.teams DROP CONSTRAINT IF EXISTS teams_captain_id_fkey;
ALTER TABLE public.teams ADD CONSTRAINT teams_captain_id_fkey 
    FOREIGN KEY (captain_id) REFERENCES public.student_master(id) ON DELETE SET NULL;


-- 4. Create performance indexes for search, filtering, and pagination
CREATE INDEX IF NOT EXISTS idx_student_master_academic_year ON public.student_master(academic_year);
CREATE INDEX IF NOT EXISTS idx_student_master_semester ON public.student_master(semester);
CREATE INDEX IF NOT EXISTS idx_student_master_branch_year ON public.student_master(branch, year);
CREATE INDEX IF NOT EXISTS idx_student_master_source ON public.student_master(source);
CREATE INDEX IF NOT EXISTS idx_student_master_usn_prefix ON public.student_master(usn varchar_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_student_master_name_prefix ON public.student_master(name varchar_pattern_ops);
