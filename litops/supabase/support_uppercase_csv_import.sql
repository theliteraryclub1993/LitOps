-- ============================================================================
-- LitOps: Support direct CSV/Excel imports with uppercase/spaced headers
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New Query)
-- ============================================================================

-- 1. Add uppercase column aliases to public.student_master
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS "SL.NO" TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS "ACADEMIC YEAR" TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS "USN" TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS "STUDENT NAME" TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS "DEPARTMENT" TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS "YEAR" TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS "EMAIL" TEXT;
ALTER TABLE public.student_master ADD COLUMN IF NOT EXISTS "GENDER" TEXT;

-- 2. Helper function to normalize branch from department name
CREATE OR REPLACE FUNCTION public.normalize_branch_from_dept(dept TEXT)
RETURNS TEXT AS $$
DECLARE
    d TEXT;
BEGIN
    IF dept IS NULL THEN
        RETURN 'UNKNOWN';
    END IF;
    
    d := UPPER(TRIM(dept));
    
    IF d LIKE '%COMPUTER SCIENCE%' OR d = 'CS' OR d = 'CSE' THEN
        IF d LIKE '%AI%' OR d LIKE '%ML%' THEN RETURN 'CI'; END IF;
        IF d LIKE '%BUSINESS%' OR d LIKE '%BS%' OR d = 'CSBS' THEN RETURN 'CB'; END IF;
        RETURN 'CSE';
    END IF;
    
    IF d LIKE '%INFORMATION SCIENCE%' OR d = 'IS' OR d = 'ISE' THEN
        RETURN 'ISE';
    END IF;
    
    IF d LIKE '%ELECTRONICS%' OR d = 'EC' OR d = 'ECE' THEN
        RETURN 'ECE';
    END IF;
    
    IF d LIKE '%ELECTRICAL%' OR d = 'EE' OR d = 'EEE' THEN
        RETURN 'EE';
    END IF;
    
    IF d LIKE '%MECHANICAL%' OR d = 'ME' THEN
        RETURN 'ME';
    END IF;
    
    IF d LIKE '%CIVIL%' OR d = 'CV' OR d = 'CE' THEN
        RETURN 'CV';
    END IF;
    
    IF d LIKE '%VLSI%' OR d = 'VL' THEN
        RETURN 'VL';
    END IF;
    
    IF d LIKE '%ROBOTICS%' OR d = 'RI' OR d = 'RAI' THEN
        RETURN 'RI';
    END IF;
    
    IF d LIKE '%ELECTRONICS & COMPUTER%' OR d LIKE '%ELECTRONICS AND COMPUTER%' OR d = 'EI' THEN
        RETURN 'EI';
    END IF;
    
    IF d = 'CI' OR d = 'AIML' THEN RETURN 'CI'; END IF;
    IF d = 'CB' OR d = 'CSBS' THEN RETURN 'CB'; END IF;
    
    RETURN d;
END;
$$ LANGUAGE plpgsql;

-- 3. Stored Procedure / Trigger to sync uppercase columns to lowercase columns
CREATE OR REPLACE FUNCTION public.sync_uppercase_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync "USN" to usn
    IF NEW."USN" IS NOT NULL AND NEW.usn IS NULL THEN
        NEW.usn := UPPER(TRIM(NEW."USN"));
    END IF;

    -- Sync "STUDENT NAME" to name
    IF NEW."STUDENT NAME" IS NOT NULL AND NEW.name IS NULL THEN
        NEW.name := UPPER(TRIM(NEW."STUDENT NAME"));
    END IF;

    -- Sync "DEPARTMENT" to branch
    IF NEW."DEPARTMENT" IS NOT NULL AND NEW.branch IS NULL THEN
        NEW.branch := public.normalize_branch_from_dept(NEW."DEPARTMENT");
    END IF;

    -- Sync "YEAR" to year
    IF NEW."YEAR" IS NOT NULL AND NEW.year IS NULL THEN
        NEW.year := COALESCE(NULLIF(regexp_replace(NEW."YEAR", '\D', '', 'g'), '')::integer, 1);
    END IF;

    -- Sync "EMAIL" to email
    IF NEW."EMAIL" IS NOT NULL AND NEW.email IS NULL THEN
        NEW.email := TRIM(NEW."EMAIL");
    END IF;

    -- Sync "GENDER" to gender
    IF NEW."GENDER" IS NOT NULL AND NEW.gender IS NULL THEN
        NEW.gender := UPPER(TRIM(NEW."GENDER"));
    END IF;

    -- Sync "ACADEMIC YEAR" to academic_year
    IF NEW."ACADEMIC YEAR" IS NOT NULL AND NEW.academic_year IS NULL THEN
        NEW.academic_year := TRIM(NEW."ACADEMIC YEAR");
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create BEFORE INSERT OR UPDATE trigger
DROP TRIGGER IF EXISTS trg_sync_uppercase_columns ON public.student_master;
CREATE TRIGGER trg_sync_uppercase_columns
BEFORE INSERT OR UPDATE ON public.student_master
FOR EACH ROW EXECUTE FUNCTION public.sync_uppercase_columns();
