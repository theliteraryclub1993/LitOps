-- LitOps Database Schema
-- The Literary Club (LIT), Malnad College of Engineering
-- Complete schema with 25 tables, RLS, triggers, and seed data

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- ENUM TYPES
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM (
      'super_admin',
      'student_president',
      'student_vice_president',
      'joint_secretary',
      'event_director',
      'event_manager',
      'database_manager',
      'photography_head',
      'assistant_coordinator',
      'junior_wing'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_category') THEN
    CREATE TYPE event_category AS ENUM (
      'balwaan',
      'buddhimaan',
      'darpan',
      'kalakruthi'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_status') THEN
    CREATE TYPE event_status AS ENUM (
      'draft',
      'upcoming',
      'registration_open',
      'registration_closed',
      'ongoing',
      'completed',
      'results_published',
      'archived'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'registration_method') THEN
    CREATE TYPE registration_method AS ENUM (
      'barcode',
      'usn_search',
      'manual'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'appeal_status') THEN
    CREATE TYPE appeal_status AS ENUM (
      'submitted',
      'under_review',
      'resolved',
      'rejected'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'appeal_type') THEN
    CREATE TYPE appeal_type AS ENUM (
      'registration_issue',
      'attendance_issue',
      'score_dispute'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'certificate_type') THEN
    CREATE TYPE certificate_type AS ENUM (
      'participation',
      'winner',
      'runner_up',
      'second_runner_up',
      'volunteer'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'result_position') THEN
    CREATE TYPE result_position AS ENUM (
      'winner',
      'runner_up',
      'second_runner_up'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'assignment_role') THEN
    CREATE TYPE assignment_role AS ENUM (
      'primary_handler',
      'secondary_handler',
      'support_member',
      'photographer',
      'volunteer'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'round_status') THEN
    CREATE TYPE round_status AS ENUM (
      'pending',
      'in_progress',
      'completed'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'student_status') THEN
    CREATE TYPE student_status AS ENUM (
      'active',
      'inactive',
      'graduated'
    );
  END IF;
END $$;

-- ============================================================================
-- TABLES
-- ============================================================================

-- 1. PROFILES
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'junior_wing',
  phone TEXT,
  photo_url TEXT,
  date_of_birth DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. STUDENT MASTER
CREATE TABLE student_master (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usn TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  branch TEXT NOT NULL,
  year INTEGER NOT NULL CHECK (year BETWEEN 1 AND 4),
  section TEXT,
  phone TEXT,
  email TEXT,
  gender TEXT,
  stream TEXT,
  photo_url TEXT,
  status student_status NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. STUDENT DATABASE BACKUPS
CREATE TABLE student_database_backups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  backup_name TEXT NOT NULL,
  record_count INTEGER NOT NULL,
  backup_data JSONB NOT NULL,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. DATABASE IMPORT HISTORY
CREATE TABLE database_import_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL CHECK (file_type IN ('csv', 'excel')),
  total_records INTEGER NOT NULL DEFAULT 0,
  successful_imports INTEGER NOT NULL DEFAULT 0,
  failed_imports INTEGER NOT NULL DEFAULT 0,
  errors JSONB,
  imported_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. EVENTS
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  category event_category NOT NULL,
  description TEXT,
  rules TEXT,
  venue TEXT,
  event_date DATE,
  event_time TIME,
  poster_url TEXT,
  capacity INTEGER,
  team_size INTEGER DEFAULT 1,
  is_team_event BOOLEAN NOT NULL DEFAULT false,
  registration_deadline TIMESTAMPTZ,
  status event_status NOT NULL DEFAULT 'draft',
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. EVENT ASSIGNMENTS
CREATE TABLE event_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  assignment_role assignment_role NOT NULL,
  assigned_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, user_id, assignment_role)
);

-- 7. PARTICIPATION CONSTRAINTS
CREATE TABLE participation_constraints (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  branch TEXT NOT NULL,
  max_participants INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, branch)
);

-- 8. TEAMS (must be before registrations due to FK)
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  team_name TEXT NOT NULL,
  captain_id UUID REFERENCES student_master(id),
  registered_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. REGISTRATIONS
CREATE TABLE registrations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES student_master(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  registration_method registration_method NOT NULL DEFAULT 'barcode',
  registered_by UUID NOT NULL REFERENCES profiles(id),
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_cancelled BOOLEAN NOT NULL DEFAULT false,
  cancelled_at TIMESTAMPTZ,
  cancelled_by UUID REFERENCES profiles(id),
  UNIQUE(event_id, student_id)
);

-- 10. TEAM MEMBERS
CREATE TABLE team_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES student_master(id) ON DELETE CASCADE,
  is_captain BOOLEAN NOT NULL DEFAULT false,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(team_id, student_id)
);

-- 11. WAITING LIST
CREATE TABLE waiting_list (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES student_master(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  promoted_at TIMESTAMPTZ,
  is_promoted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE(event_id, student_id)
);

-- 12. ATTENDANCE
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  registration_id UUID NOT NULL REFERENCES registrations(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES student_master(id) ON DELETE CASCADE,
  marked_by UUID REFERENCES profiles(id),
  marked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  method registration_method NOT NULL DEFAULT 'barcode',
  is_offline BOOLEAN NOT NULL DEFAULT false,
  synced_at TIMESTAMPTZ,
  UNIQUE(event_id, registration_id)
);

-- 13. EVENT ROUNDS
CREATE TABLE event_rounds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  round_number INTEGER NOT NULL,
  round_name TEXT NOT NULL,
  description TEXT,
  status round_status NOT NULL DEFAULT 'pending',
  qualification_criteria TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, round_number)
);

-- 14. ROUND SCORES
CREATE TABLE round_scores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  round_id UUID NOT NULL REFERENCES event_rounds(id) ON DELETE CASCADE,
  registration_id UUID NOT NULL REFERENCES registrations(id) ON DELETE CASCADE,
  score DECIMAL(10,2),
  remarks TEXT,
  is_qualified BOOLEAN,
  scored_by UUID REFERENCES profiles(id),
  scored_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(round_id, registration_id)
);

-- 15. RESULTS
CREATE TABLE results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  registration_id UUID NOT NULL REFERENCES registrations(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  position result_position NOT NULL,
  score DECIMAL(10,2),
  remarks TEXT,
  published_at TIMESTAMPTZ,
  published_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, registration_id)
);

-- 16. CERTIFICATES
CREATE TABLE certificates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES student_master(id) ON DELETE CASCADE,
  certificate_type certificate_type NOT NULL,
  certificate_url TEXT,
  qr_code TEXT NOT NULL DEFAULT uuid_generate_v4()::TEXT,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  issued_by UUID REFERENCES profiles(id)
);

-- 17. FEEDBACK
CREATE TABLE feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  student_id UUID REFERENCES student_master(id) ON DELETE SET NULL,
  event_quality INTEGER CHECK (event_quality BETWEEN 1 AND 5),
  venue_rating INTEGER CHECK (venue_rating BETWEEN 1 AND 5),
  organization_rating INTEGER CHECK (organization_rating BETWEEN 1 AND 5),
  comments TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, student_id)
);

-- 18. APPEALS
CREATE TABLE appeals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES student_master(id) ON DELETE CASCADE,
  appeal_type appeal_type NOT NULL,
  description TEXT NOT NULL,
  status appeal_status NOT NULL DEFAULT 'submitted',
  resolution TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 19. SARVOTTAM POINTS
CREATE TABLE sarvottam_points (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  branch TEXT NOT NULL,
  student_id UUID REFERENCES student_master(id) ON DELETE SET NULL,
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  points INTEGER NOT NULL DEFAULT 0,
  reason TEXT NOT NULL,
  position result_position,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 20. AUDIT LOGS
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  user_role user_role,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 21. ANNOUNCEMENTS
CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 1 CHECK (priority BETWEEN 1 AND 5),
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 22. INCIDENTS
CREATE TABLE incidents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  severity INTEGER NOT NULL DEFAULT 1 CHECK (severity BETWEEN 1 AND 5),
  reported_by UUID NOT NULL REFERENCES profiles(id),
  resolved BOOLEAN NOT NULL DEFAULT false,
  resolution TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 23. GALLERY
CREATE TABLE gallery (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video', 'document')),
  file_url TEXT NOT NULL,
  caption TEXT,
  uploaded_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 24. NOTIFICATIONS
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 25. OFFLINE SYNC QUEUE
CREATE TABLE offline_sync_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  payload JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'synced', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_student_master_usn ON student_master(usn);
CREATE INDEX idx_student_master_branch ON student_master(branch);
CREATE INDEX idx_student_master_status ON student_master(status);
CREATE INDEX idx_student_master_name ON student_master(name);
CREATE INDEX idx_events_category ON events(category);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_date ON events(event_date);
CREATE INDEX idx_event_assignments_event ON event_assignments(event_id);
CREATE INDEX idx_event_assignments_user ON event_assignments(user_id);
CREATE INDEX idx_registrations_event ON registrations(event_id);
CREATE INDEX idx_registrations_student ON registrations(student_id);
CREATE INDEX idx_registrations_team ON registrations(team_id);
CREATE INDEX idx_teams_event ON teams(event_id);
CREATE INDEX idx_team_members_team ON team_members(team_id);
CREATE INDEX idx_team_members_student ON team_members(student_id);
CREATE INDEX idx_waiting_list_event ON waiting_list(event_id);
CREATE INDEX idx_waiting_list_position ON waiting_list(event_id, position);
CREATE INDEX idx_attendance_event ON attendance(event_id);
CREATE INDEX idx_attendance_student ON attendance(student_id);
CREATE INDEX idx_event_rounds_event ON event_rounds(event_id);
CREATE INDEX idx_round_scores_round ON round_scores(round_id);
CREATE INDEX idx_round_scores_registration ON round_scores(registration_id);
CREATE INDEX idx_results_event ON results(event_id);
CREATE INDEX idx_results_registration ON results(registration_id);
CREATE INDEX idx_certificates_event ON certificates(event_id);
CREATE INDEX idx_certificates_student ON certificates(student_id);
CREATE INDEX idx_certificates_qr ON certificates(qr_code);
CREATE INDEX idx_feedback_event ON feedback(event_id);
CREATE INDEX idx_appeals_event ON appeals(event_id);
CREATE INDEX idx_appeals_status ON appeals(status);
CREATE INDEX idx_sarvottam_points_event ON sarvottam_points(event_id);
CREATE INDEX idx_sarvottam_points_branch ON sarvottam_points(branch);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX idx_announcements_event ON announcements(event_id);
CREATE INDEX idx_incidents_event ON incidents(event_id);
CREATE INDEX idx_gallery_event ON gallery(event_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(user_id, is_read);
CREATE INDEX idx_offline_sync_user ON offline_sync_queue(user_id);
CREATE INDEX idx_offline_sync_status ON offline_sync_queue(status);
CREATE INDEX idx_participation_constraints_event ON participation_constraints(event_id);

-- ============================================================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER set_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON student_master FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON event_rounds FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON appeals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON incidents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SARVOTTAM POINTS AUTO-CALCULATION TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_sarvottam_points()
RETURNS TRIGGER AS $$
DECLARE
  v_branch TEXT;
  v_points INTEGER;
  v_reason TEXT;
  v_event_id UUID;
BEGIN
  SELECT event_id INTO v_event_id FROM registrations WHERE id = NEW.registration_id;
  
  SELECT branch INTO v_branch 
  FROM student_master sm 
  JOIN registrations r ON r.student_id = sm.id 
  WHERE r.id = NEW.registration_id;

  CASE NEW.position
    WHEN 'winner' THEN v_points := 10; v_reason := 'Winner';
    WHEN 'runner_up' THEN v_points := 7; v_reason := 'Runner-Up';
    WHEN 'second_runner_up' THEN v_points := 5; v_reason := 'Second Runner-Up';
  END CASE;

  INSERT INTO sarvottam_points (event_id, branch, student_id, points, reason, position)
  VALUES (v_event_id, v_branch, (SELECT student_id FROM registrations WHERE id = NEW.registration_id), v_points, v_reason, NEW.position);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_sarvottam_points
AFTER INSERT ON results
FOR EACH ROW EXECUTE FUNCTION calculate_sarvottam_points();

-- ============================================================================
-- PARTICIPATION POINT FOR SARVOTTAM
-- ============================================================================
CREATE OR REPLACE FUNCTION add_participation_point()
RETURNS TRIGGER AS $$
DECLARE
  v_branch TEXT;
  v_event_id UUID;
BEGIN
  IF NEW.is_cancelled = false THEN
    SELECT branch INTO v_branch FROM student_master WHERE id = NEW.student_id;
    v_event_id := NEW.event_id;

    INSERT INTO sarvottam_points (event_id, branch, student_id, points, reason)
    VALUES (v_event_id, v_branch, NEW.student_id, 1, 'Participation');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_add_participation_point
AFTER INSERT ON registrations
FOR EACH ROW EXECUTE FUNCTION add_participation_point();

-- ============================================================================
-- WAITING LIST AUTO-PROMOTION TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION promote_waiting_list()
RETURNS TRIGGER AS $$
DECLARE
  v_next_waiting UUID;
  v_student_id UUID;
  v_event_id UUID;
BEGIN
  IF NEW.is_cancelled = true AND OLD.is_cancelled = false THEN
    v_event_id := NEW.event_id;

    SELECT id, student_id INTO v_next_waiting, v_student_id
    FROM waiting_list
    WHERE event_id = v_event_id AND is_promoted = false
    ORDER BY position ASC
    LIMIT 1;

    IF v_next_waiting IS NOT NULL THEN
      INSERT INTO registrations (event_id, student_id, registration_method, registered_by)
      VALUES (v_event_id, v_student_id, 'barcode', (SELECT cancelled_by FROM registrations WHERE id = NEW.id));

      UPDATE waiting_list SET is_promoted = true, promoted_at = NOW() WHERE id = v_next_waiting;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_promote_waiting_list
AFTER UPDATE OF is_cancelled ON registrations
FOR EACH ROW EXECUTE FUNCTION promote_waiting_list();

-- ============================================================================
-- AUDIT LOG TRIGGER FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION log_audit_action()
RETURNS TRIGGER AS $$
DECLARE
  v_action TEXT;
  v_entity_type TEXT;
BEGIN
  v_entity_type := TG_TABLE_NAME;
  
  IF TG_OP = 'INSERT' THEN
    v_action := 'CREATE';
    INSERT INTO audit_logs (action, entity_type, entity_id, details, created_at)
    VALUES (v_action, v_entity_type, NEW.id, to_jsonb(NEW), NOW());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    v_action := 'UPDATE';
    INSERT INTO audit_logs (action, entity_type, entity_id, details, created_at)
    VALUES (v_action, v_entity_type, NEW.id, jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)), NOW());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'DELETE';
    INSERT INTO audit_logs (action, entity_type, entity_id, details, created_at)
    VALUES (v_action, v_entity_type, OLD.id, to_jsonb(OLD), NOW());
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_events AFTER INSERT OR UPDATE OR DELETE ON events FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER trg_audit_registrations AFTER INSERT OR UPDATE OR DELETE ON registrations FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER trg_audit_results AFTER INSERT OR UPDATE OR DELETE ON results FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER trg_audit_certificates AFTER INSERT OR UPDATE OR DELETE ON certificates FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER trg_audit_student_master AFTER INSERT OR UPDATE OR DELETE ON student_master FOR EACH ROW EXECUTE FUNCTION log_audit_action();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_database_backups ENABLE ROW LEVEL SECURITY;
ALTER TABLE database_import_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE participation_constraints ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE waiting_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE round_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE results ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE sarvottam_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE gallery ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_sync_queue ENABLE ROW LEVEL SECURITY;

-- Helper function to check user role
CREATE OR REPLACE FUNCTION is_role(required_role user_role)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = required_role AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role IN ('student_president', 'student_vice_president', 'joint_secretary', 'event_director') AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user can manage event assignments (Super Admin, Event Managers, and all 4th year members)
CREATE OR REPLACE FUNCTION can_manage_event_assignments()
RETURNS BOOLEAN AS $$
DECLARE
  v_role user_role;
  v_year INTEGER;
BEGIN
  SELECT role, year INTO v_role, v_year 
  FROM profiles 
  WHERE id = auth.uid() AND is_active = true;
  
  RETURN v_role = 'student_president'::user_role -- president is part of user_role enum
      OR v_role = 'super_admin'::user_role -- override if super_admin is added
      OR v_role = 'event_manager'::user_role 
      OR v_year = 4;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PROFILES RLS
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON profiles FOR SELECT USING (is_admin());
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- STUDENT MASTER RLS
CREATE POLICY "Authenticated users can view students" ON student_master FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins and DB managers can insert students" ON student_master FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('database_manager'));
CREATE POLICY "Admins and DB managers can update students" ON student_master FOR UPDATE TO authenticated USING (is_admin() OR is_role('database_manager'));
CREATE POLICY "President can delete students" ON student_master FOR DELETE TO authenticated USING (is_role('student_president'));

-- STUDENT DATABASE BACKUPS RLS
CREATE POLICY "Admins can view backups" ON student_database_backups FOR SELECT TO authenticated USING (is_admin());
CREATE POLICY "Admins and DB managers can create backups" ON student_database_backups FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('database_manager'));

-- DATABASE IMPORT HISTORY RLS
CREATE POLICY "Admins can view import history" ON database_import_history FOR SELECT TO authenticated USING (is_admin() OR is_role('database_manager'));
CREATE POLICY "Admins and DB managers can create import history" ON database_import_history FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('database_manager'));

-- EVENTS RLS
CREATE POLICY "Authenticated users can view events" ON events FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins and event managers can create events" ON events FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('event_manager'));
CREATE POLICY "Admins and event managers can update events" ON events FOR UPDATE TO authenticated USING (is_admin() OR is_role('event_manager') OR created_by = auth.uid());
CREATE POLICY "Admins can delete events" ON events FOR DELETE TO authenticated USING (is_admin());

-- EVENT ASSIGNMENTS RLS
CREATE POLICY "Authenticated users can view assignments" ON event_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage assignments" ON event_assignments FOR ALL TO authenticated USING (can_manage_event_assignments());

-- PARTICIPATION CONSTRAINTS RLS
CREATE POLICY "Authenticated users can view constraints" ON participation_constraints FOR SELECT TO authenticated USING (true);
CREATE POLICY "Event directors can manage constraints" ON participation_constraints FOR ALL TO authenticated USING (is_role('event_director') OR is_admin());

-- REGISTRATIONS RLS
CREATE POLICY "Authenticated users can view registrations" ON registrations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can create registrations" ON registrations FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('event_manager') OR is_role('assistant_coordinator'));
CREATE POLICY "Authorized roles can update registrations" ON registrations FOR UPDATE TO authenticated USING (is_admin() OR is_role('event_manager'));

-- TEAMS RLS
CREATE POLICY "Authenticated users can view teams" ON teams FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage teams" ON teams FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- TEAM MEMBERS RLS
CREATE POLICY "Authenticated users can view team members" ON team_members FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage team members" ON team_members FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- WAITING LIST RLS
CREATE POLICY "Authenticated users can view waiting list" ON waiting_list FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage waiting list" ON waiting_list FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- ATTENDANCE RLS
CREATE POLICY "Authenticated users can view attendance" ON attendance FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can mark attendance" ON attendance FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('event_manager') OR is_role('assistant_coordinator'));
CREATE POLICY "Authorized roles can update attendance" ON attendance FOR UPDATE TO authenticated USING (is_admin());

-- EVENT ROUNDS RLS
CREATE POLICY "Authenticated users can view rounds" ON event_rounds FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage rounds" ON event_rounds FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- ROUND SCORES RLS
CREATE POLICY "Authenticated users can view scores" ON round_scores FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage scores" ON round_scores FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- RESULTS RLS
CREATE POLICY "Authenticated users can view results" ON results FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage results" ON results FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- CERTIFICATES RLS
CREATE POLICY "Authenticated users can view certificates" ON certificates FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage certificates" ON certificates FOR ALL TO authenticated USING (is_admin());
CREATE POLICY "Public can verify certificates" ON certificates FOR SELECT TO anon USING (true);

-- FEEDBACK RLS
CREATE POLICY "Authenticated users can view feedback" ON feedback FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can submit feedback" ON feedback FOR INSERT TO authenticated WITH CHECK (true);

-- APPEALS RLS
CREATE POLICY "Users can view own appeals" ON appeals FOR SELECT TO authenticated USING (student_id IN (SELECT id FROM student_master WHERE usn = (SELECT email FROM profiles WHERE id = auth.uid())) OR is_admin());
CREATE POLICY "Authenticated users can submit appeals" ON appeals FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update appeals" ON appeals FOR UPDATE TO authenticated USING (is_admin());

-- SARVOTTAM POINTS RLS
CREATE POLICY "Authenticated users can view sarvottam points" ON sarvottam_points FOR SELECT TO authenticated USING (true);
CREATE POLICY "System can insert sarvottam points" ON sarvottam_points FOR INSERT TO authenticated WITH CHECK (true);

-- AUDIT LOGS RLS
CREATE POLICY "Admins can view audit logs" ON audit_logs FOR SELECT TO authenticated USING (is_admin());

-- ANNOUNCEMENTS RLS
CREATE POLICY "Authenticated users can view announcements" ON announcements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage announcements" ON announcements FOR ALL TO authenticated USING (is_admin());

-- INCIDENTS RLS
CREATE POLICY "Authenticated users can view incidents" ON incidents FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage incidents" ON incidents FOR ALL TO authenticated USING (is_admin());

-- GALLERY RLS
CREATE POLICY "Authenticated users can view gallery" ON gallery FOR SELECT TO authenticated USING (true);
CREATE POLICY "Photography head and admins can manage gallery" ON gallery FOR ALL TO authenticated USING (is_admin() OR is_role('photography_head'));

-- NOTIFICATIONS RLS
CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "System can create notifications" ON notifications FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- OFFLINE SYNC QUEUE RLS
CREATE POLICY "Users can manage own sync queue" ON offline_sync_queue FOR ALL TO authenticated USING (user_id = auth.uid());

-- ============================================================================
-- REALTIME PUBLICATION
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE registrations;
ALTER PUBLICATION supabase_realtime ADD TABLE attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE results;
ALTER PUBLICATION supabase_realtime ADD TABLE sarvottam_points;
ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE waiting_list;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- ====================================================================
-- ADMIN USER SETUP (Run these steps on the NEW Supabase project)
-- ====================================================================
--
-- Step 1: In Supabase Dashboard > Authentication > Providers > Email
--   - Make sure Email provider is ENABLED
--   - Turn OFF "Confirm email" (so admin can login immediately)
--
-- Step 2: In Supabase Dashboard > Authentication > Users > Add User
--   - Email: theliteraryclubmce@gmail.com
--   - Password: Malnad2K27
--   - Toggle ON "Auto Confirm User"
--   - Click "Create User"
--
-- Step 3: Copy the User UUID from the Users list and run:
--
-- INSERT INTO profiles (id, email, full_name, role)
-- VALUES (
--   'PASTE_USER_UUID_HERE',
--   'theliteraryclubmce@gmail.com',
--   'Super Admin',
--   'student_president'
-- );
--
-- OR: Just login with the admin credentials in the app.
-- The app will auto-create the profile with student_president role
-- if the email matches theliteraryclubmce@gmail.com.
-- ====================================================================

-- Sample events for testing (uncomment after admin profile is created)
-- INSERT INTO events (name, category, description, venue, event_date, capacity, team_size, status, created_by)
-- VALUES 
--   ('Pentathlon', 'balwaan', 'Five-event sports challenge', 'Main Ground', '2026-07-15', 100, 1, 'registration_open', 'ADMIN_USER_ID'),
--   ('Quiz', 'buddhimaan', 'General knowledge quiz competition', 'Seminar Hall', '2026-07-15', 50, 2, 'registration_open', 'ADMIN_USER_ID'),
--   ('Group Singing', 'darpan', 'Team singing performance', 'Auditorium', '2026-07-16', 20, 8, 'draft', 'ADMIN_USER_ID'),
--   ('Pot Painting', 'kalakruthi', 'Creative pot painting competition', 'Art Room', '2026-07-16', 30, 1, 'upcoming', 'ADMIN_USER_ID');
