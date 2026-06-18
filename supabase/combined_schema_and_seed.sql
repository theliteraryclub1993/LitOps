-- ============================================================================
-- LITOPS - UNIFIED DATABASE SCHEMA & DEMO DATA SEED
-- ============================================================================
-- The Literary Club (LIT), Malnad College of Engineering (MCE)
-- Run this complete script in the Supabase SQL Editor to initialize
-- the database, configure RLS, and seed production-grade demo data.
-- ============================================================================

-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- CLEANUP (Ensures clean deployment)
DROP TRIGGER IF EXISTS trg_auto_promote_super_admin ON profiles;
DROP TRIGGER IF EXISTS trg_check_participation_limit ON registrations;
DROP TRIGGER IF EXISTS trg_check_venue_conflict ON event_schedules;
DROP TRIGGER IF EXISTS trg_enforce_max_4_years ON yearly_archives;
DROP TRIGGER IF EXISTS trg_audit_events ON events;
DROP TRIGGER IF EXISTS trg_audit_registrations ON registrations;
DROP TRIGGER IF EXISTS trg_audit_results ON results;
DROP TRIGGER IF EXISTS trg_audit_certificates ON certificates;
DROP TRIGGER IF EXISTS trg_audit_student_master ON student_master;
DROP TRIGGER IF EXISTS trg_calculate_sarvottam_points ON results;
DROP TRIGGER IF EXISTS trg_add_participation_point ON registrations;
DROP TRIGGER IF EXISTS trg_promote_waiting_list ON registrations;

DROP TABLE IF EXISTS search_history CASCADE;
DROP TABLE IF EXISTS barcode_logs CASCADE;
DROP TABLE IF EXISTS event_schedules CASCADE;
DROP TABLE IF EXISTS event_points CASCADE;
DROP TABLE IF EXISTS department_rankings CASCADE;
DROP TABLE IF EXISTS audit_extended CASCADE;
DROP TABLE IF EXISTS yearly_imports CASCADE;
DROP TABLE IF EXISTS yearly_archives CASCADE;
DROP TABLE IF EXISTS member_assignments CASCADE;
DROP TABLE IF EXISTS role_permissions CASCADE;
DROP TABLE IF EXISTS permissions CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS offline_sync_queue CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS gallery CASCADE;
DROP TABLE IF EXISTS incidents CASCADE;
DROP TABLE IF EXISTS announcements CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS sarvottam_points CASCADE;
DROP TABLE IF EXISTS appeals CASCADE;
DROP TABLE IF EXISTS feedback CASCADE;
DROP TABLE IF EXISTS certificates CASCADE;
DROP TABLE IF EXISTS results CASCADE;
DROP TABLE IF EXISTS round_scores CASCADE;
DROP TABLE IF EXISTS event_rounds CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS waiting_list CASCADE;
DROP TABLE IF EXISTS team_members CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS registrations CASCADE;
DROP TABLE IF EXISTS participation_constraints CASCADE;
DROP TABLE IF EXISTS event_assignments CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS database_import_history CASCADE;
DROP TABLE IF EXISTS student_database_backups CASCADE;
DROP TABLE IF EXISTS student_master CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS event_category CASCADE;
DROP TYPE IF EXISTS event_status CASCADE;
DROP TYPE IF EXISTS registration_method CASCADE;
DROP TYPE IF EXISTS appeal_status CASCADE;
DROP TYPE IF EXISTS appeal_type CASCADE;
DROP TYPE IF EXISTS certificate_type CASCADE;
DROP TYPE IF EXISTS result_position CASCADE;
DROP TYPE IF EXISTS assignment_role CASCADE;
DROP TYPE IF EXISTS round_status CASCADE;
DROP TYPE IF EXISTS student_status CASCADE;
DROP TYPE IF EXISTS member_status CASCADE;

-- ============================================================================
-- ENUM TYPES
-- ============================================================================
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

CREATE TYPE event_category AS ENUM (
  'balwaan',
  'buddhimaan',
  'darpan',
  'kalakruthi'
);

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

CREATE TYPE registration_method AS ENUM (
  'barcode',
  'usn_search',
  'manual'
);

CREATE TYPE appeal_status AS ENUM (
  'submitted',
  'under_review',
  'resolved',
  'rejected'
);

CREATE TYPE appeal_type AS ENUM (
  'registration_issue',
  'attendance_issue',
  'score_dispute'
);

CREATE TYPE certificate_type AS ENUM (
  'participation',
  'winner',
  'runner_up',
  'second_runner_up',
  'volunteer'
);

CREATE TYPE result_position AS ENUM (
  'winner',
  'runner_up',
  'second_runner_up'
);

CREATE TYPE assignment_role AS ENUM (
  'primary_handler',
  'secondary_handler',
  'support_member',
  'photographer',
  'volunteer'
);

CREATE TYPE round_status AS ENUM (
  'pending',
  'in_progress',
  'completed'
);

CREATE TYPE student_status AS ENUM (
  'active',
  'inactive',
  'graduated'
);

CREATE TYPE member_status AS ENUM (
  'active',
  'suspended',
  'inactive'
);

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
  is_active BOOLEAN NOT NULL DEFAULT true,
  date_of_birth DATE,
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

-- 8. TEAMS
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
-- GOVERNANCE & ACCESS CONTROL EXTENSION TABLES
-- ============================================================================

-- 26. ROLES (Named role definitions with hierarchy)
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  hierarchy_level INTEGER NOT NULL DEFAULT 99,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 27. PERMISSIONS (Granular permission definitions)
CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 28. ROLE_PERMISSIONS (Many-to-many mapping)
CREATE TABLE role_permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(role_id, permission_id)
);

-- 29. MEMBER_ASSIGNMENTS (Club member management)
CREATE TABLE member_assignments (
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

-- 30. YEARLY_ARCHIVES (Year-wise fest data – max 4 years)
CREATE TABLE yearly_archives (
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

-- 31. YEARLY_IMPORTS (Historical CSV/Excel import records)
CREATE TABLE yearly_imports (
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

-- 32. AUDIT_EXTENDED (Extended audit with IP, device, old/new values)
CREATE TABLE audit_extended (
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

-- 33. DEPARTMENT_RANKINGS (Materialized ranking cache)
CREATE TABLE department_rankings (
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

-- 34. EVENT_POINTS (Super Admin managed point allocations)
CREATE TABLE event_points (
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

-- 35. EVENT_SCHEDULES (Event scheduling with venue conflict detection)
CREATE TABLE event_schedules (
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

-- 36. BARCODE_LOGS (Scan history for registration)
CREATE TABLE barcode_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  student_id UUID REFERENCES student_master(id) ON DELETE SET NULL,
  barcode_data TEXT NOT NULL,
  scan_result TEXT NOT NULL CHECK (scan_result IN ('success', 'duplicate', 'invalid', 'not_found', 'limit_reached')),
  scanned_by UUID REFERENCES profiles(id),
  device_info TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 37. SEARCH_HISTORY (User search history for suggestions)
CREATE TABLE search_history (
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

-- Trigram indexes for fuzzy search
CREATE INDEX idx_student_master_name_trgm ON student_master USING gin (name gin_trgm_ops);
CREATE INDEX idx_student_master_usn_trgm ON student_master USING gin (usn gin_trgm_ops);

-- Full-text search index on events
CREATE INDEX idx_events_fts ON events USING gin (
  to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, ''))
);

-- New governance indexes
CREATE INDEX idx_roles_hierarchy ON roles(hierarchy_level);
CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX idx_role_permissions_perm ON role_permissions(permission_id);
CREATE INDEX idx_member_assignments_user ON member_assignments(user_id);
CREATE INDEX idx_member_assignments_status ON member_assignments(status);
CREATE INDEX idx_member_assignments_role ON member_assignments(role);
CREATE INDEX idx_yearly_archives_year ON yearly_archives(fest_year);
CREATE INDEX idx_yearly_imports_year ON yearly_imports(fest_year);
CREATE INDEX idx_yearly_imports_by ON yearly_imports(imported_by);
CREATE INDEX idx_audit_extended_user ON audit_extended(user_id);
CREATE INDEX idx_audit_extended_action ON audit_extended(action);
CREATE INDEX idx_audit_extended_entity ON audit_extended(entity_type, entity_id);
CREATE INDEX idx_audit_extended_created ON audit_extended(created_at);
CREATE INDEX idx_department_rankings_year ON department_rankings(fest_year);
CREATE INDEX idx_department_rankings_branch ON department_rankings(branch);
CREATE INDEX idx_event_points_event ON event_points(event_id);
CREATE INDEX idx_event_points_branch ON event_points(branch);
CREATE INDEX idx_event_schedules_event ON event_schedules(event_id);
CREATE INDEX idx_event_schedules_date ON event_schedules(schedule_date);
CREATE INDEX idx_event_schedules_venue ON event_schedules(venue, schedule_date);
CREATE INDEX idx_barcode_logs_event ON barcode_logs(event_id);
CREATE INDEX idx_barcode_logs_student ON barcode_logs(student_id);
CREATE INDEX idx_barcode_logs_result ON barcode_logs(scan_result);
CREATE INDEX idx_search_history_user ON search_history(user_id);
CREATE INDEX idx_search_history_query ON search_history(query);

-- ============================================================================
-- TRIGGER FUNCTIONS
-- ============================================================================

-- 1. UPDATED_AT TRIGGER FUNCTION
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
CREATE TRIGGER set_updated_at BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON member_assignments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON yearly_archives FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON event_points FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON event_schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 2. SARVOTTAM POINTS AUTO-CALCULATION TRIGGER
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

-- 3. PARTICIPATION POINT FOR SARVOTTAM
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

-- 4. WAITING LIST AUTO-PROMOTION TRIGGER
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

-- 5. AUDIT LOG TRIGGER FUNCTION
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

-- 6. ENFORCE MAX 4 YEARS TRIGGER
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

-- 7. VENUE CONFLICT DETECTION FUNCTION
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

-- 8. PARTICIPATION LIMIT CHECK TRIGGER
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

-- 9. EXTENDED AUDIT TRIGGER
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

-- Apply extended audit triggers
CREATE TRIGGER trg_audit_ext_member_assignments AFTER INSERT OR UPDATE OR DELETE ON member_assignments FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_event_points AFTER INSERT OR UPDATE OR DELETE ON event_points FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_event_schedules AFTER INSERT OR UPDATE OR DELETE ON event_schedules FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_yearly_archives AFTER INSERT OR UPDATE OR DELETE ON yearly_archives FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_yearly_imports AFTER INSERT ON yearly_imports FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_sarvottam_points AFTER INSERT OR UPDATE OR DELETE ON sarvottam_points FOR EACH ROW EXECUTE FUNCTION log_audit_extended();
CREATE TRIGGER trg_audit_ext_profiles AFTER UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION log_audit_extended();

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- 1. Check if the current user has the required role (with super_admin override)
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

-- 2. Check if the current user is an Admin
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

-- 3. Check if the current user is Super Admin
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'super_admin' AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Check if the current user is Core Committee
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

-- 5. Check if the current user is Event Director
CREATE OR REPLACE FUNCTION is_event_director()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('super_admin', 'event_director') AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5b. Check if the current user can manage event assignments (Super Admin, Event Managers, and all 4th year members)
CREATE OR REPLACE FUNCTION can_manage_event_assignments()
RETURNS BOOLEAN AS $$
DECLARE
  v_role user_role;
  v_year INTEGER;
BEGIN
  SELECT role, year INTO v_role, v_year 
  FROM profiles 
  WHERE id = auth.uid() AND is_active = true;
  
  RETURN v_role = 'super_admin'::user_role 
      OR v_role = 'event_manager'::user_role 
      OR v_role = 'event_manager_co_editorial'::user_role 
      OR v_year = 4;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Pre-auth Date of Birth verification (SECURITY DEFINER allows executing before session is set)
CREATE OR REPLACE FUNCTION verify_user_dob(p_email TEXT, p_dob DATE)
RETURNS TABLE (user_id UUID, role TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT id, role::TEXT
  FROM profiles
  WHERE email = p_email AND date_of_birth = p_dob AND is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Global fuzzy search across students, events, teams, members
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
    e.name,
    (e.category::TEXT || ' • ' || COALESCE(e.venue, 'TBD')),
    similarity(e.name, search_query)
  FROM events e
  WHERE e.name % search_query OR e.name ILIKE '%' || search_query || '%'

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

-- 8. Auto promote theliteraryclubmce@gmail.com to super_admin
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

CREATE TRIGGER trg_auto_promote_super_admin
BEFORE INSERT OR UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION auto_promote_super_admin();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================
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

-- Governance RLS
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE yearly_archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE yearly_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_extended ENABLE ROW LEVEL SECURITY;
ALTER TABLE department_rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE barcode_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;

-- POLICIES

-- Profiles
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON profiles FOR SELECT USING (is_admin());
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Student Master
CREATE POLICY "Authenticated users can view students" ON student_master FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins and DB managers can insert students" ON student_master FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('database_manager'));
CREATE POLICY "Admins and DB managers can update students" ON student_master FOR UPDATE TO authenticated USING (is_admin() OR is_role('database_manager'));
CREATE POLICY "President can delete students" ON student_master FOR DELETE TO authenticated USING (is_role('student_president'));

-- Backups
CREATE POLICY "Admins can view backups" ON student_database_backups FOR SELECT TO authenticated USING (is_admin());
CREATE POLICY "Admins and DB managers can create backups" ON student_database_backups FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('database_manager'));

-- Database Import History
CREATE POLICY "Admins can view import history" ON database_import_history FOR SELECT TO authenticated USING (is_admin() OR is_role('database_manager'));
CREATE POLICY "Admins and DB managers can create import history" ON database_import_history FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('database_manager'));

-- Events
CREATE POLICY "Authenticated users can view events" ON events FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins and event managers can create events" ON events FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('event_manager'));
CREATE POLICY "Admins and event managers can update events" ON events FOR UPDATE TO authenticated USING (is_admin() OR is_role('event_manager') OR created_by = auth.uid());
CREATE POLICY "Admins can delete events" ON events FOR DELETE TO authenticated USING (is_admin());

-- Event Assignments
CREATE POLICY "Authenticated users can view assignments" ON event_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage assignments" ON event_assignments FOR ALL TO authenticated USING (can_manage_event_assignments());

-- Participation Constraints
CREATE POLICY "Authenticated users can view constraints" ON participation_constraints FOR SELECT TO authenticated USING (true);
CREATE POLICY "Event directors can manage constraints" ON participation_constraints FOR ALL TO authenticated USING (is_role('event_director') OR is_admin());

-- Registrations
CREATE POLICY "Authenticated users can view registrations" ON registrations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can create registrations" ON registrations FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('event_manager') OR is_role('assistant_coordinator'));
CREATE POLICY "Authorized roles can update registrations" ON registrations FOR UPDATE TO authenticated USING (is_admin() OR is_role('event_manager'));

-- Teams
CREATE POLICY "Authenticated users can view teams" ON teams FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage teams" ON teams FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- Team Members
CREATE POLICY "Authenticated users can view team members" ON team_members FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage team members" ON team_members FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- Waiting List
CREATE POLICY "Authenticated users can view waiting list" ON waiting_list FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage waiting list" ON waiting_list FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- Attendance
CREATE POLICY "Authenticated users can view attendance" ON attendance FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can mark attendance" ON attendance FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('event_manager') OR is_role('assistant_coordinator'));
CREATE POLICY "Authorized roles can update attendance" ON attendance FOR UPDATE TO authenticated USING (is_admin());

-- Event Rounds
CREATE POLICY "Authenticated users can view rounds" ON event_rounds FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage rounds" ON event_rounds FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- Round Scores
CREATE POLICY "Authenticated users can view scores" ON round_scores FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized roles can manage scores" ON round_scores FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- Results
CREATE POLICY "Authenticated users can view results" ON results FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage results" ON results FOR ALL TO authenticated USING (is_admin() OR is_role('event_manager'));

-- Certificates
CREATE POLICY "Authenticated users can view certificates" ON certificates FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage certificates" ON certificates FOR ALL TO authenticated USING (is_admin());
CREATE POLICY "Public can verify certificates" ON certificates FOR SELECT TO anon USING (true);

-- Feedback
CREATE POLICY "Authenticated users can view feedback" ON feedback FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can submit feedback" ON feedback FOR INSERT TO authenticated WITH CHECK (true);

-- Appeals
CREATE POLICY "Users can view own appeals" ON appeals FOR SELECT TO authenticated USING (student_id IN (SELECT id FROM student_master WHERE usn = (SELECT email FROM profiles WHERE id = auth.uid())) OR is_admin());
CREATE POLICY "Authenticated users can submit appeals" ON appeals FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update appeals" ON appeals FOR UPDATE TO authenticated USING (is_admin());

-- Sarvottam Points
CREATE POLICY "Authenticated users can view sarvottam points" ON sarvottam_points FOR SELECT TO authenticated USING (true);
CREATE POLICY "System can insert sarvottam points" ON sarvottam_points FOR INSERT TO authenticated WITH CHECK (true);

-- Audit Logs
CREATE POLICY "Admins can view audit logs" ON audit_logs FOR SELECT TO authenticated USING (is_admin());

-- Announcements
CREATE POLICY "Authenticated users can view announcements" ON announcements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage announcements" ON announcements FOR ALL TO authenticated USING (is_admin());

-- Incidents
CREATE POLICY "Authenticated users can view incidents" ON incidents FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage incidents" ON incidents FOR ALL TO authenticated USING (is_admin());

-- Gallery
CREATE POLICY "Authenticated users can view gallery" ON gallery FOR SELECT TO authenticated USING (true);
CREATE POLICY "Photography head and admins can manage gallery" ON gallery FOR ALL TO authenticated USING (is_admin() OR is_role('photography_head'));

-- Notifications
CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "System can create notifications" ON notifications FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- Offline Sync Queue
CREATE POLICY "Users can manage own sync queue" ON offline_sync_queue FOR ALL TO authenticated USING (user_id = auth.uid());

-- Roles
CREATE POLICY "Authenticated users can view roles" ON roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage roles" ON roles FOR ALL TO authenticated USING (is_super_admin());

-- Permissions
CREATE POLICY "Authenticated users can view permissions" ON permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage permissions" ON permissions FOR ALL TO authenticated USING (is_super_admin());

-- Role Permissions
CREATE POLICY "Authenticated users can view role_permissions" ON role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage role_permissions" ON role_permissions FOR ALL TO authenticated USING (is_super_admin());

-- Member Assignments
CREATE POLICY "Core committee can view member assignments" ON member_assignments FOR SELECT TO authenticated USING (is_core_committee());
CREATE POLICY "Super admin can manage member assignments" ON member_assignments FOR ALL TO authenticated USING (is_super_admin());

-- Yearly Archives
CREATE POLICY "Authenticated users can view archives" ON yearly_archives FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage archives" ON yearly_archives FOR ALL TO authenticated USING (is_super_admin());

-- Yearly Imports
CREATE POLICY "Admin can view imports" ON yearly_imports FOR SELECT TO authenticated USING (is_admin());
CREATE POLICY "Super admin can manage imports" ON yearly_imports FOR ALL TO authenticated USING (is_super_admin());

-- Audit Extended
CREATE POLICY "Super admin can view extended audit" ON audit_extended FOR SELECT TO authenticated USING (is_super_admin());
CREATE POLICY "System can insert extended audit" ON audit_extended FOR INSERT TO authenticated WITH CHECK (true);

-- Department Rankings
CREATE POLICY "Authenticated users can view department rankings" ON department_rankings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage department rankings" ON department_rankings FOR ALL TO authenticated USING (is_super_admin());

-- Event Points
CREATE POLICY "Authenticated users can view event points" ON event_points FOR SELECT TO authenticated USING (true);
CREATE POLICY "Super admin can manage event points" ON event_points FOR ALL TO authenticated USING (is_super_admin());

-- Event Schedules
CREATE POLICY "Authenticated users can view schedules" ON event_schedules FOR SELECT TO authenticated USING (true);
CREATE POLICY "Event director can manage schedules" ON event_schedules FOR ALL TO authenticated USING (is_event_director());

-- Barcode Logs
CREATE POLICY "Admin can view barcode logs" ON barcode_logs FOR SELECT TO authenticated USING (is_admin());
CREATE POLICY "Authorized roles can insert barcode logs" ON barcode_logs FOR INSERT TO authenticated WITH CHECK (is_admin() OR is_role('event_manager') OR is_role('assistant_coordinator'));

-- Search History
CREATE POLICY "Users can manage own search history" ON search_history FOR ALL TO authenticated USING (user_id = auth.uid());

-- ============================================================================
-- REALTIME PUBLICATIONS
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE registrations;
ALTER PUBLICATION supabase_realtime ADD TABLE attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE results;
ALTER PUBLICATION supabase_realtime ADD TABLE sarvottam_points;
ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE waiting_list;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE event_points;
ALTER PUBLICATION supabase_realtime ADD TABLE event_schedules;
ALTER PUBLICATION supabase_realtime ADD TABLE department_rankings;
ALTER PUBLICATION supabase_realtime ADD TABLE member_assignments;

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- 1. Roles Definition
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

-- 2. Permissions Definition
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

-- 3. Seed Supabase Auth Users
-- Super Admin (theliteraryclubmce@gmail.com / Malnad2K27)
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES 
  ('d0d1e2f3-c4b5-a697-8899-aabbccddeeff', 'authenticated', 'authenticated', 'theliteraryclubmce@gmail.com', crypt('Malnad2K27', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Super Admin","date_of_birth":"2000-01-01"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Student President (president@litops.com / dob: 2004-05-10)
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES 
  ('e1111111-2222-3333-4444-555555555555', 'authenticated', 'authenticated', 'president@litops.com', crypt('2004-05-10', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Student President","date_of_birth":"2004-05-10"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Student Vice President (vp@litops.com / dob: 2004-08-12)
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES 
  ('e2222222-2222-3333-4444-555555555555', 'authenticated', 'authenticated', 'vp@litops.com', crypt('2004-08-12', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Student Vice President","date_of_birth":"2004-08-12"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Joint Secretary 1 (js1@litops.com / dob: 2004-11-20)
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES 
  ('e3333333-2222-3333-4444-555555555555', 'authenticated', 'authenticated', 'js1@litops.com', crypt('2004-11-20', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Joint Secretary 1","date_of_birth":"2004-11-20"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Event Director (director@litops.com / dob: 2004-03-22)
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES 
  ('e5555555-2222-3333-4444-555555555555', 'authenticated', 'authenticated', 'director@litops.com', crypt('2004-03-22', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Event Director","date_of_birth":"2004-03-22"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Database Manager (dbmanager@litops.com / dob: 2004-12-05)
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES 
  ('e6666666-2222-3333-4444-555555555555', 'authenticated', 'authenticated', 'dbmanager@litops.com', crypt('2004-12-05', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Database Manager","date_of_birth":"2004-12-05"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Photography Head (photohead@litops.com / dob: 2004-09-30)
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES 
  ('e7777777-2222-3333-4444-555555555555', 'authenticated', 'authenticated', 'photohead@litops.com', crypt('2004-09-30', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Photography Head","date_of_birth":"2004-09-30"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Event Manager (manager@litops.com / dob: 2005-04-18)
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES 
  ('e8888888-2222-3333-4444-555555555555', 'authenticated', 'authenticated', 'manager@litops.com', crypt('2005-04-18', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{"full_name":"Event Manager","date_of_birth":"2005-04-18"}', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- 4. Seed Profiles (linked to auth.users)
INSERT INTO profiles (id, email, full_name, role, phone, photo_url, is_active, date_of_birth) VALUES
  ('d0d1e2f3-c4b5-a697-8899-aabbccddeeff', 'theliteraryclubmce@gmail.com', 'Super Admin', 'super_admin', '9876543210', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb', true, '2000-01-01'),
  ('e1111111-2222-3333-4444-555555555555', 'president@litops.com', 'Student President', 'student_president', '9988776655', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d', true, '2004-05-10'),
  ('e2222222-2222-3333-4444-555555555555', 'vp@litops.com', 'Student Vice President', 'student_vice_president', '9876987654', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330', true, '2004-08-12'),
  ('e3333333-2222-3333-4444-555555555555', 'js1@litops.com', 'Joint Secretary 1', 'joint_secretary', '9898767654', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e', true, '2004-11-20'),
  ('e5555555-2222-3333-4444-555555555555', 'director@litops.com', 'Event Director', 'event_director', '9595959595', 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80', true, '2004-03-22'),
  ('e6666666-2222-3333-4444-555555555555', 'dbmanager@litops.com', 'Database Manager', 'database_manager', '9494949494', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e', true, '2004-12-05'),
  ('e7777777-2222-3333-4444-555555555555', 'photohead@litops.com', 'Photography Head', 'photography_head', '9393939393', 'https://images.unsplash.com/photo-1517841905240-472988babdf9', true, '2004-09-30'),
  ('e8888888-2222-3333-4444-555555555555', 'manager@litops.com', 'Event Manager', 'event_manager', '9292929292', 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7', true, '2005-04-18')
ON CONFLICT (id) DO NOTHING;

-- 5. Seed Member Assignments (Governance link)
INSERT INTO member_assignments (user_id, role, status, assigned_by) VALUES
  ('e1111111-2222-3333-4444-555555555555', 'student_president', 'active', 'd0d1e2f3-c4b5-a697-8899-aabbccddeeff'),
  ('e2222222-2222-3333-4444-555555555555', 'student_vice_president', 'active', 'd0d1e2f3-c4b5-a697-8899-aabbccddeeff'),
  ('e3333333-2222-3333-4444-555555555555', 'joint_secretary', 'active', 'd0d1e2f3-c4b5-a697-8899-aabbccddeeff'),
  ('e5555555-2222-3333-4444-555555555555', 'event_director', 'active', 'd0d1e2f3-c4b5-a697-8899-aabbccddeeff'),
  ('e6666666-2222-3333-4444-555555555555', 'database_manager', 'active', 'd0d1e2f3-c4b5-a697-8899-aabbccddeeff'),
  ('e7777777-2222-3333-4444-555555555555', 'photography_head', 'active', 'd0d1e2f3-c4b5-a697-8899-aabbccddeeff'),
  ('e8888888-2222-3333-4444-555555555555', 'event_manager', 'active', 'e5555555-2222-3333-4444-555555555555');

-- 6. Seed Student Master (20+ students representing MCE branches)
INSERT INTO student_master (id, usn, name, branch, year, section, phone, email, status) VALUES
  ('s0111111-1111-1111-1111-111111111111', '4MC23CS001', 'Abhishek Gowda', 'CSE', 3, 'A', '9845012345', 'abhishek@mce.edu', 'active'),
  ('s0222222-1111-1111-1111-111111111111', '4MC23CS002', 'Bhumika R', 'CSE', 3, 'A', '9845023456', 'bhumika@mce.edu', 'active'),
  ('s0333333-1111-1111-1111-111111111111', '4MC23CS003', 'Chetan Kumar', 'CSE', 3, 'B', '9845034567', 'chetan@mce.edu', 'active'),
  ('s0444444-1111-1111-1111-111111111111', '4MC23CS004', 'Divya M', 'CSE', 3, 'B', '9845045678', 'divya@mce.edu', 'active'),
  ('s0555555-1111-1111-1111-111111111111', '4MC23IS001', 'Eshwar Prasad', 'ISE', 3, 'A', '9845056789', 'eshwar@mce.edu', 'active'),
  ('s0666666-1111-1111-1111-111111111111', '4MC23IS002', 'Farhan Khan', 'ISE', 3, 'A', '9845067890', 'farhan@mce.edu', 'active'),
  ('s0777777-1111-1111-1111-111111111111', '4MC23IS003', 'Girish Hegde', 'ISE', 3, 'B', '9845078901', 'girish@mce.edu', 'active'),
  ('s0888888-1111-1111-1111-111111111111', '4MC23EC001', 'Harini S', 'ECE', 3, 'A', '9845089012', 'harini@mce.edu', 'active'),
  ('s0999999-1111-1111-1111-111111111111', '4MC23EC002', 'Imran Pasha', 'ECE', 3, 'A', '9845090123', 'imran@mce.edu', 'active'),
  ('s1010101-1111-1111-1111-111111111111', '4MC23EC003', 'Jyothi Sharma', 'ECE', 3, 'B', '9845001234', 'jyothi@mce.edu', 'active'),
  ('s1111112-1111-1111-1111-111111111111', '4MC24CS001', 'Karthik Rao', 'CSE', 2, 'A', '9900112233', 'karthik@mce.edu', 'active'),
  ('s1212122-1111-1111-1111-111111111111', '4MC24CS002', 'Latha Manjunath', 'CSE', 2, 'B', '9900223344', 'latha@mce.edu', 'active'),
  ('s1313132-1111-1111-1111-111111111111', '4MC24IS001', 'Manoj Kumar', 'ISE', 2, 'A', '9900334455', 'manoj@mce.edu', 'active'),
  ('s1414142-1111-1111-1111-111111111111', '4MC24EC001', 'Nisha Shetty', 'ECE', 2, 'A', '9900445566', 'nisha@mce.edu', 'active'),
  ('s1515152-1111-1111-1111-111111111111', '4MC24ME001', 'Praveen Gowda', 'ME', 2, 'A', '9900556677', 'praveen@mce.edu', 'active'),
  ('s1616162-1111-1111-1111-111111111111', '4MC25CS001', 'Rahul Dravid', 'CSE', 1, 'A', '9911112222', 'rahul@mce.edu', 'active'),
  ('s1717172-1111-1111-1111-111111111111', '4MC25IS001', 'Sneha Ram', 'ISE', 1, 'A', '9922223333', 'sneha@mce.edu', 'active'),
  ('s1818182-1111-1111-1111-111111111111', '4MC25EC001', 'Tarun Dev', 'ECE', 1, 'A', '9933334444', 'tarun@mce.edu', 'active'),
  ('s1919192-1111-1111-1111-111111111111', '4MC25ME001', 'Varun Tej', 'ME', 1, 'A', '9944445555', 'varun@mce.edu', 'active'),
  ('s2020202-1111-1111-1111-111111111111', '4MC22CS001', 'Vijay Kumar', 'CSE', 4, 'A', '9888112233', 'vijay@mce.edu', 'active'),
  ('s2121212-1111-1111-1111-111111111111', '4MC22IS001', 'Yashaswini K', 'ISE', 4, 'A', '9888223344', 'yashaswini@mce.edu', 'active')
ON CONFLICT (id) DO NOTHING;

-- 7. Seed Events (8+ events representing variety of categories)
INSERT INTO events (id, name, category, description, rules, venue, event_date, event_time, capacity, team_size, is_team_event, status, created_by) VALUES
  ('v0111111-2222-3333-4444-555555555555', 'Pentathlon', 'balwaan', 'Five-event sports challenge containing Sprint, Shotput, Long Jump, Discus, and Hurdles.', 'Each participant must compete in all 5 sub-events. Standard athletic scoring rules apply.', 'Main Ground', '2026-07-15', '09:00:00', 50, 1, false, 'registration_open', 'e5555555-2222-3333-4444-555555555555'),
  ('v0222222-2222-3333-4444-555555555555', 'Brain Squeeze Quiz', 'buddhimaan', 'A classic trivia challenge focusing on history, science, literature, and general awareness.', 'A team must have exactly 2 members. Standard general quiz scoring rules. Prelims round followed by finals.', 'Seminar Hall 1', '2026-07-15', '14:00:00', 10, 2, true, 'registration_open', 'e5555555-2222-3333-4444-555555555555'),
  ('v0333333-2222-3333-4444-555555555555', 'Darpan Group Dance', 'darpan', 'Stage choreography competition showcasing folk, classical, and contemporary dance forms.', 'Team size 6 to 12. Maximum duration: 8 minutes. Songs must be pre-approved.', 'Auditorium', '2026-07-16', '10:00:00', 15, 6, true, 'registration_open', 'e5555555-2222-3333-4444-555555555555'),
  ('v0444444-2222-3333-4444-555555555555', 'Clay Modeling', 'kalakruthi', 'Creative sculpting competition using natural clay on theme "Future of Technology".', 'Duration: 3 hours. Clay will be provided. No external accessories/tools allowed.', 'Art Room', '2026-07-16', '11:00:00', 25, 1, false, 'upcoming', 'e5555555-2222-3333-4444-555555555555'),
  ('v0555555-2222-3333-4444-555555555555', 'Debate Challenge', 'buddhimaan', 'Inter-branch Oxford style debate on modern ethical issues.', 'Individual participation. Speakers will get 4 minutes for and 2 minutes against.', 'Seminar Hall 2', '2026-07-17', '09:00:00', 20, 1, false, 'upcoming', 'e5555555-2222-3333-4444-555555555555'),
  ('v0666666-2222-3333-4444-555555555555', 'Street Play', 'darpan', 'Nukkad Natak highlighting modern social issues and local college lore.', 'Team size: 8 to 15. Max duration: 15 minutes. Props allowed, no electric audio.', 'Amphitheater', '2026-07-17', '13:00:00', 12, 8, true, 'upcoming', 'e5555555-2222-3333-4444-555555555555'),
  ('v0777777-2222-3333-4444-555555555555', 'Blitz Chess', 'balwaan', 'Rapid action blitz tournament, Swiss system, 5 minutes + 3 seconds increment.', 'FIDE rules apply. Arbiter decision is final. Strict Swiss format.', 'Library Hall', '2026-07-18', '10:00:00', 32, 1, false, 'draft', 'e5555555-2222-3333-4444-555555555555'),
  ('v0888888-2222-3333-4444-555555555555', 'Canvas Painting', 'kalakruthi', 'Water color/acrylic painting on a canvas sheet provided by the club.', 'Time limit: 2 hours. Theme: "Colors of Hope". Bring your own painting gear.', 'Art Room', '2026-07-18', '11:00:00', 40, 1, false, 'draft', 'e5555555-2222-3333-4444-555555555555')
ON CONFLICT (id) DO NOTHING;

-- 8. Seed Event Schedules
INSERT INTO event_schedules (event_id, schedule_date, start_time, end_time, venue, is_parallel, parallel_group, volunteer_count, coordinator_id, notes, status, created_by) VALUES
  ('v0111111-2222-3333-4444-555555555555', '2026-07-15', '09:00:00', '13:00:00', 'Main Ground', false, NULL, 15, 'e1111111-2222-3333-4444-555555555555', 'Ensure first-aid kit and water points are ready.', 'scheduled', 'e5555555-2222-3333-4444-555555555555'),
  ('v0222222-2222-3333-4444-555555555555', '2026-07-15', '14:00:00', '17:00:00', 'Seminar Hall 1', false, NULL, 6, 'e3333333-2222-3333-4444-555555555555', 'Set up AV system, buzzers, and slides.', 'scheduled', 'e5555555-2222-3333-4444-555555555555'),
  ('v0333333-2222-3333-4444-555555555555', '2026-07-16', '10:00:00', '16:00:00', 'Auditorium', false, NULL, 20, 'e7777777-2222-3333-4444-555555555555', 'Check lighting effects and sound systems.', 'scheduled', 'e5555555-2222-3333-4444-555555555555');

-- 9. Seed Event Participation Constraints
INSERT INTO participation_constraints (event_id, branch, max_participants, created_at) VALUES
  ('v0111111-2222-3333-4444-555555555555', 'CSE', 5, NOW()),
  ('v0111111-2222-3333-4444-555555555555', 'ISE', 4, NOW()),
  ('v0222222-2222-3333-4444-555555555555', 'CSE', 2, NOW());

-- 10. Seed Event Assignments (Volunteers and Handlers)
INSERT INTO event_assignments (event_id, user_id, assignment_role, assigned_by) VALUES
  ('v0111111-2222-3333-4444-555555555555', 'e8888888-2222-3333-4444-555555555555', 'primary_handler', 'e5555555-2222-3333-4444-555555555555'),
  ('v0111111-2222-3333-4444-555555555555', 'e7777777-2222-3333-4444-555555555555', 'photographer', 'e5555555-2222-3333-4444-555555555555'),
  ('v0222222-2222-3333-4444-555555555555', 'e8888888-2222-3333-4444-555555555555', 'secondary_handler', 'e5555555-2222-3333-4444-555555555555');

-- 11. Seed Registrations
INSERT INTO registrations (id, event_id, student_id, team_id, registration_method, registered_by) VALUES
  -- Sprint (Individual)
  ('r0111111-3333-4444-5555-666666666666', 'v0111111-2222-3333-4444-555555555555', 's0111111-1111-1111-1111-111111111111', NULL, 'barcode', 'e8888888-2222-3333-4444-555555555555'),
  ('r0222222-3333-4444-5555-666666666666', 'v0111111-2222-3333-4444-555555555555', 's0333333-1111-1111-1111-111111111111', NULL, 'manual', 'e1111111-2222-3333-4444-555555555555'),
  ('r0333333-3333-4444-5555-666666666666', 'v0111111-2222-3333-4444-555555555555', 's0555555-1111-1111-1111-111111111111', NULL, 'barcode', 'e8888888-2222-3333-4444-555555555555'),
  ('r0444444-3333-4444-5555-666666666666', 'v0111111-2222-3333-4444-555555555555', 's0888888-1111-1111-1111-111111111111', NULL, 'usn_search', 'e8888888-2222-3333-4444-555555555555');

-- 12. Seed Attendance
INSERT INTO attendance (event_id, registration_id, student_id, marked_by, method) VALUES
  ('v0111111-2222-3333-4444-555555555555', 'r0111111-3333-4444-5555-666666666666', 's0111111-1111-1111-1111-111111111111', 'e8888888-2222-3333-4444-555555555555', 'barcode'),
  ('v0111111-2222-3333-4444-555555555555', 'r0333333-3333-4444-5555-666666666666', 's0555555-1111-1111-1111-111111111111', 'e8888888-2222-3333-4444-555555555555', 'barcode'),
  ('v0111111-2222-3333-4444-555555555555', 'r0444444-3333-4444-5555-666666666666', 's0888888-1111-1111-1111-111111111111', 'e8888888-2222-3333-4444-555555555555', 'usn_search');

-- 13. Seed Event Rounds
INSERT INTO event_rounds (id, event_id, round_number, round_name, description, status) VALUES
  ('d0111111-4444-5555-6666-777777777777', 'v0111111-2222-3333-4444-555555555555', 1, 'Qualifiers', 'Initial timing heats to qualify top 8.', 'completed'),
  ('d0222222-4444-5555-6666-777777777777', 'v0111111-2222-3333-4444-555555555555', 2, 'Finals', 'Ultimate sprint to declare winner.', 'pending');

-- 14. Seed Round Scores
INSERT INTO round_scores (round_id, registration_id, score, remarks, is_qualified, scored_by) VALUES
  ('d0111111-4444-5555-6666-777777777777', 'r0111111-3333-4444-5555-666666666666', 11.24, 'Finished 1st in heat 1', true, 'e8888888-2222-3333-4444-555555555555'),
  ('d0111111-4444-5555-6666-777777777777', 'r0333333-3333-4444-5555-666666666666', 12.11, 'Finished 2nd in heat 2', true, 'e8888888-2222-3333-4444-555555555555'),
  ('d0111111-4444-5555-6666-777777777777', 'r0444444-3333-4444-5555-666666666666', 12.45, 'Finished 3rd in heat 1', false, 'e8888888-2222-3333-4444-555555555555');

-- 15. Seed Results (For 2026 leaderboards)
INSERT INTO results (event_id, registration_id, position, score, remarks, published_by, published_at) VALUES
  ('v0111111-2222-3333-4444-555555555555', 'r0111111-3333-4444-5555-666666666666', 'winner', 10.95, 'New record sprint time!', 'e5555555-2222-3333-4444-555555555555', NOW()),
  ('v0111111-2222-3333-4444-555555555555', 'r0333333-3333-4444-5555-666666666666', 'runner_up', 11.50, 'Very close finish.', 'e5555555-2222-3333-4444-555555555555', NOW());

-- 16. Seed Department Rankings Cache
INSERT INTO department_rankings (fest_year, branch, total_points, total_participations, total_wins, total_runner_ups, total_second_runner_ups, rank_position) VALUES
  (2026, 'CSE', 11, 2, 1, 0, 0, 1),
  (2026, 'ISE', 8, 2, 0, 1, 0, 2),
  (2026, 'ECE', 1, 1, 0, 0, 0, 3),
  (2026, 'ME', 0, 0, 0, 0, 0, 4);

-- 17. Seed Yearly Archives (Fest Data Rotation - seeding 3 years, max 4 limit)
INSERT INTO yearly_archives (fest_year, fest_name, total_events, total_registrations, total_participants, total_attendance, is_active) VALUES
  (2023, 'Malnad Fest 2023', 12, 180, 150, 140, false),
  (2024, 'Malnad Fest 2024', 15, 230, 210, 195, false),
  (2025, 'Malnad Fest 2025', 18, 310, 290, 270, false);

-- 18. Seed Audit extended logs
INSERT INTO audit_extended (user_id, user_email, user_role, action, entity_type, entity_id, previous_value, new_value, ip_address, device_info) VALUES
  ('d0d1e2f3-c4b5-a697-8899-aabbccddeeff', 'theliteraryclubmce@gmail.com', 'super_admin', 'CREATE', 'member_assignments', 'e8888888-2222-3333-4444-555555555555', NULL, '{"role": "event_manager", "status": "active"}'::jsonb, '127.0.0.1', 'Desktop Console (Chrome)');

-- 19. Seed Feedback entries
INSERT INTO feedback (event_id, student_id, event_quality, venue_rating, organization_rating, comments) VALUES
  ('v0111111-2222-3333-4444-555555555555', 's0888888-1111-1111-1111-111111111111', 5, 4, 5, 'Pentathlon qualifiers were very well managed!');
