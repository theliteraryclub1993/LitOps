-- ============================================================================
-- LitOps Enterprise Admin & Governance Extension
-- Migration file – run AFTER the base schema.sql
-- ============================================================================

-- ============================================================================
-- EXTENSIONS FOR SEARCH
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- ENUM MODIFICATIONS
-- ============================================================================
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'super_admin';

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'member_status') THEN
    CREATE TYPE member_status AS ENUM ('active', 'suspended', 'inactive');
  END IF;
END $$;

-- ============================================================================
-- TABLE MODIFICATIONS
-- ============================================================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS year INTEGER CHECK (year BETWEEN 1 AND 4);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS usn TEXT;

-- Notify PostgREST to reload the schema cache so the API immediately recognizes the new columns
NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- NEW TABLES
-- ============================================================================

-- 1. ROLES (Named role definitions with hierarchy)
CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  hierarchy_level INTEGER NOT NULL DEFAULT 99,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. PERMISSIONS (Granular permission definitions)
CREATE TABLE IF NOT EXISTS permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. ROLE_PERMISSIONS (Many-to-many mapping)
CREATE TABLE IF NOT EXISTS role_permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(role_id, permission_id)
);

-- 4. MEMBER_ASSIGNMENTS (Club member management)
CREATE TABLE IF NOT EXISTS member_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role user_role NOT NULL,
  status member_status NOT NULL DEFAULT 'active',
  assigned_by UUID NOT NULL REFERENCES profiles(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  suspended_at TIMESTAMPTZ,
  suspended_reason TEXT,
  reactivated_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. YEARLY_ARCHIVES (Year-wise fest data – max 4 years)
CREATE TABLE IF NOT EXISTS yearly_archives (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  fest_year INTEGER NOT NULL UNIQUE CHECK (fest_year >= 2020 AND fest_year <= 2099),
  fest_name TEXT NOT NULL DEFAULT 'Malnad Fest',
  total_events INTEGER NOT NULL DEFAULT 0,
  total_registrations INTEGER NOT NULL DEFAULT 0,
  total_participants INTEGER NOT NULL DEFAULT 0,
  total_attendance INTEGER NOT NULL DEFAULT 0,
  archive_data JSONB,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. YEARLY_IMPORTS (Historical CSV/Excel import records)
CREATE TABLE IF NOT EXISTS yearly_imports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  fest_year INTEGER NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL CHECK (file_type IN ('csv', 'excel')),
  total_records INTEGER NOT NULL DEFAULT 0,
  successful_imports INTEGER NOT NULL DEFAULT 0,
  failed_imports INTEGER NOT NULL DEFAULT 0,
  duplicate_count INTEGER NOT NULL DEFAULT 0,
  import_data JSONB,
  error_log JSONB,
  validation_report JSONB,
  imported_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. AUDIT_EXTENDED (Extended audit with IP, device, old/new values)
CREATE TABLE IF NOT EXISTS audit_extended (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  user_email TEXT,
  user_role user_role,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  previous_value JSONB,
  new_value JSONB,
  ip_address TEXT,
  device_info TEXT,
  user_agent TEXT,
  session_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. DEPARTMENT_RANKINGS (Materialized ranking cache)
CREATE TABLE IF NOT EXISTS department_rankings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  fest_year INTEGER NOT NULL,
  branch TEXT NOT NULL,
  total_points INTEGER NOT NULL DEFAULT 0,
  total_participations INTEGER NOT NULL DEFAULT 0,
  total_wins INTEGER NOT NULL DEFAULT 0,
  total_runner_ups INTEGER NOT NULL DEFAULT 0,
  total_second_runner_ups INTEGER NOT NULL DEFAULT 0,
  rank_position INTEGER,
  last_calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(fest_year, branch)
);

-- 9. EVENT_POINTS (Super Admin managed point allocations)
CREATE TABLE IF NOT EXISTS event_points (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  branch TEXT NOT NULL,
  student_id UUID REFERENCES student_master(id) ON DELETE SET NULL,
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  points INTEGER NOT NULL DEFAULT 0,
  reason TEXT NOT NULL,
  position result_position,
  allocated_by UUID NOT NULL REFERENCES profiles(id),
  approved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. EVENT_SCHEDULES (Event scheduling with venue conflict detection)
CREATE TABLE IF NOT EXISTS event_schedules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  schedule_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  venue TEXT NOT NULL,
  is_parallel BOOLEAN NOT NULL DEFAULT false,
  parallel_group TEXT,
  volunteer_count INTEGER NOT NULL DEFAULT 0,
  coordinator_id UUID REFERENCES profiles(id),
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT no_negative_duration CHECK (end_time > start_time)
);

-- 11. BARCODE_LOGS (Scan history for registration)
CREATE TABLE IF NOT EXISTS barcode_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  student_id UUID REFERENCES student_master(id) ON DELETE SET NULL,
  barcode_data TEXT NOT NULL,
  scan_result TEXT NOT NULL CHECK (scan_result IN ('success', 'duplicate', 'invalid', 'not_found', 'limit_reached')),
  scanned_by UUID REFERENCES profiles(id),
  device_info TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. SEARCH_HISTORY (User search history for suggestions)
CREATE TABLE IF NOT EXISTS search_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  result_type TEXT,
  result_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Trigram indexes for fuzzy search
CREATE INDEX IF NOT EXISTS idx_student_master_name_trgm ON student_master USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_student_master_usn_trgm ON student_master USING gin (usn gin_trgm_ops);

-- Full-text search index on events
CREATE INDEX IF NOT EXISTS idx_events_fts ON events USING gin (
  to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, ''))
);

-- New table indexes
CREATE INDEX IF NOT EXISTS idx_roles_hierarchy ON roles(hierarchy_level);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_perm ON role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_member_assignments_user ON member_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_member_assignments_status ON member_assignments(status);
CREATE INDEX IF NOT EXISTS idx_member_assignments_role ON member_assignments(role);
CREATE INDEX IF NOT EXISTS idx_yearly_archives_year ON yearly_archives(fest_year);
CREATE INDEX IF NOT EXISTS idx_yearly_imports_year ON yearly_imports(fest_year);
CREATE INDEX IF NOT EXISTS idx_yearly_imports_by ON yearly_imports(imported_by);
CREATE INDEX IF NOT EXISTS idx_audit_extended_user ON audit_extended(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_extended_action ON audit_extended(action);
CREATE INDEX IF NOT EXISTS idx_audit_extended_entity ON audit_extended(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_extended_created ON audit_extended(created_at);
CREATE INDEX IF NOT EXISTS idx_department_rankings_year ON department_rankings(fest_year);
CREATE INDEX IF NOT EXISTS idx_department_rankings_branch ON department_rankings(branch);
CREATE INDEX IF NOT EXISTS idx_event_points_event ON event_points(event_id);
CREATE INDEX IF NOT EXISTS idx_event_points_branch ON event_points(branch);
CREATE INDEX IF NOT EXISTS idx_event_schedules_event ON event_schedules(event_id);
CREATE INDEX IF NOT EXISTS idx_event_schedules_date ON event_schedules(schedule_date);
CREATE INDEX IF NOT EXISTS idx_event_schedules_venue ON event_schedules(venue, schedule_date);
CREATE INDEX IF NOT EXISTS idx_barcode_logs_event ON barcode_logs(event_id);
CREATE INDEX IF NOT EXISTS idx_barcode_logs_student ON barcode_logs(student_id);
CREATE INDEX IF NOT EXISTS idx_barcode_logs_result ON barcode_logs(scan_result);
CREATE INDEX IF NOT EXISTS idx_search_history_user ON search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_search_history_query ON search_history(query);

-- ============================================================================
-- UPDATED_AT TRIGGERS FOR NEW TABLES
-- ============================================================================
CREATE TRIGGER set_updated_at BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON member_assignments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON yearly_archives FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON event_points FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON event_schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ENFORCE MAX 4 YEARS TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION enforce_max_4_years()
RETURNS TRIGGER AS $$
DECLARE
  year_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO year_count FROM yearly_archives;
  IF year_count >= 4 THEN
    RAISE EXCEPTION 'Maximum storage limit reached (4 years). Please delete the oldest fest database before importing a new year.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_max_4_years
BEFORE INSERT ON yearly_archives
FOR EACH ROW EXECUTE FUNCTION enforce_max_4_years();

-- ============================================================================
-- VENUE CONFLICT DETECTION FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION check_venue_conflict()
RETURNS TRIGGER AS $$
DECLARE
  conflict_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO conflict_count
  FROM event_schedules
  WHERE venue = NEW.venue
    AND schedule_date = NEW.schedule_date
    AND id != COALESCE(NEW.id, uuid_generate_v4())
    AND status != 'cancelled'
    AND (
      (NEW.start_time >= start_time AND NEW.start_time < end_time)
      OR (NEW.end_time > start_time AND NEW.end_time <= end_time)
      OR (NEW.start_time <= start_time AND NEW.end_time >= end_time)
    );

  IF conflict_count > 0 AND NEW.is_parallel = false THEN
    RAISE EXCEPTION 'Venue conflict detected: % is already booked on % between the specified times.', NEW.venue, NEW.schedule_date;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_venue_conflict
BEFORE INSERT OR UPDATE ON event_schedules
FOR EACH ROW EXECUTE FUNCTION check_venue_conflict();

-- ============================================================================
-- PARTICIPATION LIMIT CHECK TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION check_participation_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_branch TEXT;
  v_max INTEGER;
  v_current INTEGER;
BEGIN
  -- Get the student's branch
  SELECT branch INTO v_branch FROM student_master WHERE id = NEW.student_id;

  -- Check if there's a branch-wise constraint for this event
  SELECT max_participants INTO v_max
  FROM participation_constraints
  WHERE event_id = NEW.event_id AND branch = v_branch;

  IF v_max IS NOT NULL THEN
    -- Count current registrations for this branch+event
    SELECT COUNT(*) INTO v_current
    FROM registrations r
    JOIN student_master s ON s.id = r.student_id
    WHERE r.event_id = NEW.event_id
      AND s.branch = v_branch
      AND r.is_cancelled = false;

    IF v_current >= v_max THEN
      RAISE EXCEPTION 'Branch participation limit reached: % has reached the maximum of % participants for this event.', v_branch, v_max;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_participation_limit
BEFORE INSERT ON registrations
FOR EACH ROW EXECUTE FUNCTION check_participation_limit();

-- ============================================================================
-- EXTENDED AUDIT TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION log_audit_extended()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_extended (user_id, action, entity_type, entity_id, new_value, created_at)
    VALUES (auth.uid(), 'CREATE', TG_TABLE_NAME, NEW.id, to_jsonb(NEW), NOW());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_extended (user_id, action, entity_type, entity_id, previous_value, new_value, created_at)
    VALUES (auth.uid(), 'UPDATE', TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW), NOW());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO audit_extended (user_id, action, entity_type, entity_id, previous_value, created_at)
    VALUES (auth.uid(), 'DELETE', TG_TABLE_NAME, OLD.id, to_jsonb(OLD), NOW());
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply extended audit to critical tables
CREATE TRIGGER trg_audit_ext_member_assignments AFTER INSERT OR UPDATE OR DELETE ON member_assignments FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_event_points AFTER INSERT OR UPDATE OR DELETE ON event_points FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_event_schedules AFTER INSERT OR UPDATE OR DELETE ON event_schedules FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_yearly_archives AFTER INSERT OR UPDATE OR DELETE ON yearly_archives FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_yearly_imports AFTER INSERT ON yearly_imports FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_sarvottam_points AFTER INSERT OR UPDATE OR DELETE ON sarvottam_points FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_profiles AFTER UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION log_audit_extended();

-- ============================================================================
-- SEARCH FUNCTIONS
-- ============================================================================

-- Global fuzzy search across students, events, teams
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

  -- Team name search
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

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Check if the current user is Super Admin
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin' AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if the current user is Core Committee
CREATE OR REPLACE FUNCTION is_core_committee()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('super_admin', 'student_president', 'student_vice_president', 'joint_secretary', 'event_director', 'database_manager', 'photography_head')
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if the current user is Event Director
CREATE OR REPLACE FUNCTION is_event_director()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('super_admin', 'event_director') AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the existing is_admin to include super_admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('super_admin', 'student_president', 'student_vice_president', 'joint_secretary', 'event_director')
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the existing is_role to automatically grant all roles to super_admin
CREATE OR REPLACE FUNCTION is_role(required_role user_role)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
      AND (role = required_role OR role = 'super_admin') 
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS policy to allow users to insert their own profile
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Automatically promote theliteraryclubmce@gmail.com to super_admin on profile creation or update
CREATE OR REPLACE FUNCTION auto_promote_super_admin()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email = 'theliteraryclubmce@gmail.com' THEN
    NEW.role := 'super_admin'::user_role;
    NEW.is_active := true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auto_promote_super_admin ON profiles;
CREATE TRIGGER trg_auto_promote_super_admin
BEFORE INSERT OR UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION auto_promote_super_admin();


-- ============================================================================
-- ROW LEVEL SECURITY FOR NEW TABLES
-- ============================================================================

-- ROLES
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view roles" ON roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage roles" ON roles FOR ALL TO authenticated USING (is_super_admin());

-- PERMISSIONS
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view permissions" ON permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage permissions" ON permissions FOR ALL TO authenticated USING (is_super_admin());

-- ROLE_PERMISSIONS
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view role_permissions" ON role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage role_permissions" ON role_permissions FOR ALL TO authenticated USING (is_super_admin());

-- MEMBER_ASSIGNMENTS
ALTER TABLE member_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Core committee can view member assignments" ON member_assignments FOR SELECT TO authenticated USING (is_core_committee());
CREATE POLICY "Super admin can manage member assignments" ON member_assignments FOR ALL TO authenticated USING (is_super_admin());

-- YEARLY_ARCHIVES
ALTER TABLE yearly_archives ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view archives" ON yearly_archives FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage archives" ON yearly_archives FOR ALL TO authenticated USING (is_super_admin());

-- YEARLY_IMPORTS
ALTER TABLE yearly_imports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin can view imports" ON yearly_imports FOR SELECT TO authenticated USING (is_admin());
CREATE POLICY "Super admin can manage imports" ON yearly_imports FOR ALL TO authenticated USING (is_super_admin());

-- AUDIT_EXTENDED
ALTER TABLE audit_extended ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Super admin can view extended audit" ON audit_extended FOR SELECT TO authenticated USING (is_super_admin());
CREATE POLICY "System can insert extended audit" ON audit_extended FOR INSERT TO authenticated WITH CHECK (true);

-- DEPARTMENT_RANKINGS
ALTER TABLE department_rankings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view department rankings" ON department_rankings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage department rankings" ON department_rankings FOR ALL TO authenticated USING (is_super_admin());

-- EVENT_POINTS
ALTER TABLE event_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view event points" ON event_points FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage event points" ON event_points FOR ALL TO authenticated USING (is_super_admin());

-- EVENT_SCHEDULES
ALTER TABLE event_schedules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view schedules" ON event_schedules FOR SELECT TO authenticated USING (true);
CREATE POLICY "Event director can manage schedules" ON event_schedules FOR ALL TO authenticated USING (is_event_director());

-- BARCODE_LOGS
ALTER TABLE barcode_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin can view barcode logs" ON barcode_logs FOR SELECT TO authenticated USING (is_admin());
CREATE POLICY "Authorized roles can insert barcode logs" ON barcode_logs FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('event_manager') OR is_role('assistant_coordinator'));

-- SEARCH_HISTORY
ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own search history" ON search_history FOR ALL TO authenticated USING (user_id = auth.uid());

-- ============================================================================
-- REALTIME PUBLICATION FOR NEW TABLES
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE event_points;
ALTER PUBLICATION supabase_realtime ADD TABLE event_schedules;
ALTER PUBLICATION supabase_realtime ADD TABLE department_rankings;
ALTER PUBLICATION supabase_realtime ADD TABLE member_assignments;

-- ============================================================================
-- SEED DATA: ROLES & PERMISSIONS
-- ============================================================================
INSERT INTO roles (name, display_name, hierarchy_level, description) VALUES
  ('super_admin', 'Super Admin', 0, 'Complete unrestricted access to all system features'),
  ('student_president', 'Student President', 1, 'Head of the Literary Club with broad administrative access'),
  ('student_vice_president', 'Student Vice President', 2, 'Deputy head with read-only operational visibility'),
  ('joint_secretary_1', 'Joint Secretary 1', 3, 'Core committee member with read-only access'),
  ('joint_secretary_2', 'Joint Secretary 2', 3, 'Core committee member with read-only access'),
  ('event_director', 'Event Director', 4, 'Manages event operations, scheduling, and assignments'),
  ('database_manager', 'Database Manager', 5, 'Manages student database and imports'),
  ('photography_head', 'Photography Head', 6, 'Manages event gallery and media'),
  ('event_manager', 'Event Manager', 7, 'Handles specific event operations'),
  ('assistant_coordinator', 'Assistant Coordinator', 8, 'Assists event managers with registrations'),
  ('junior_wing', 'Junior Wing', 9, 'Basic read-only access')
ON CONFLICT (name) DO NOTHING;

INSERT INTO permissions (name, display_name, category) VALUES
  ('manage_members', 'Manage Members', 'admin'),
  ('assign_roles', 'Assign Roles', 'admin'),
  ('manage_yearly_data', 'Manage Yearly Data', 'admin'),
  ('edit_points', 'Edit Sarvottam Points', 'admin'),
  ('view_audit_logs', 'View Audit Logs', 'admin'),
  ('reset_database', 'Reset Database', 'admin'),
  ('manage_events', 'Manage Events', 'events'),
  ('manage_event_schedule', 'Manage Event Schedule', 'events'),
  ('assign_event_members', 'Assign Event Members', 'events'),
  ('register_participants', 'Register Participants', 'registration'),
  ('edit_registrations', 'Edit Registrations', 'registration'),
  ('mark_attendance', 'Mark Attendance', 'attendance'),
  ('manage_results', 'Manage Results', 'results'),
  ('generate_certificates', 'Generate Certificates', 'certificates'),
  ('manage_gallery', 'Manage Gallery', 'gallery'),
  ('view_analytics', 'View Analytics', 'analytics'),
  ('import_data', 'Import Data', 'data'),
  ('export_data', 'Export Data', 'data'),
  ('manage_appeals', 'Manage Appeals', 'appeals')
ON CONFLICT (name) DO NOTHING;
