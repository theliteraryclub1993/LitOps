-- ============================================================================
-- LitOps Seed Demo Data — RUN THIS IN SUPABASE SQL EDITOR
-- Dashboard > SQL Editor > New Query > Paste this > Click RUN
-- ============================================================================

DO $$
DECLARE
  v_admin_id UUID;
BEGIN
  -- 1. Identify or default the Super Admin ID
  SELECT id INTO v_admin_id FROM auth.users WHERE email = 'theliteraryclubmce@gmail.com' LIMIT 1;
  
  IF v_admin_id IS NULL THEN
    SELECT id INTO v_admin_id FROM public.profiles WHERE email = 'theliteraryclubmce@gmail.com' LIMIT 1;
  END IF;
  
  IF v_admin_id IS NULL THEN
    -- Fallback dummy UUID if admin is not registered yet
    v_admin_id := '61bff047-a01c-4cf3-98ba-694647930ccf';
  END IF;

  RAISE NOTICE 'Using Admin ID: %', v_admin_id;

  -- 2. Ensure the Admin Profile exists
  INSERT INTO public.profiles (id, email, full_name, role, is_active, year, date_of_birth, created_at, updated_at)
  VALUES (
    v_admin_id,
    'theliteraryclubmce@gmail.com',
    'The Literary Club Admin',
    'super_admin'::user_role,
    true,
    4,
    '2000-01-01'::date,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET role = 'super_admin'::user_role,
      is_active = true;

  -- 3. Seed Demo Students
  INSERT INTO public.student_master (id, usn, name, branch, year, section, phone, email, status, created_at, updated_at)
  VALUES
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b1', '4MC22CS001', 'Aditya Sharma', 'CSE', 3, 'A', '+91 9876543210', 'aditya.sharma@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b2', '4MC22IS024', 'Riya Sen', 'ISE', 3, 'B', '+91 9876543211', 'riya.sen@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b3', '4MC23EC056', 'Rohan Gupta', 'ECE', 2, 'A', '+91 9876543212', 'rohan.gupta@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b4', '4MC23ME012', 'Sneha Reddy', 'ME', 2, 'B', '+91 9876543213', 'sneha.reddy@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b5', '4MC24EE089', 'Vikram Gowda', 'EEE', 1, 'A', '+91 9876543214', 'vikram.gowda@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b6', '4MC24CV034', 'Ananya Hegde', 'CIVIL', 1, 'B', '+91 9876543215', 'ananya.hegde@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b7', '4MC25IP005', 'Prajwal K', 'IPE', 1, 'A', '+91 9876543216', 'prajwal.k@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b8', '4MC25CH018', 'Kirti Naik', 'CH', 1, 'A', '+91 9876543217', 'kirti.naik@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b9', '4MC22CS045', 'Manoj Kumar', 'CSE', 3, 'B', '+91 9876543218', 'manoj.kumar@gmail.com', 'active'::student_status, NOW(), NOW()),
    ('a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1c0', '4MC23IS015', 'Divya S', 'ISE', 2, 'A', '+91 9876543219', 'divya.s@gmail.com', 'active'::student_status, NOW(), NOW())
  ON CONFLICT (usn) DO NOTHING;

  -- 4. Seed Demo Events
  INSERT INTO public.events (id, name, category, description, rules, venue, event_date, event_time, poster_url, capacity, team_size, is_team_event, registration_deadline, status, created_by, created_at, updated_at)
  VALUES
    (
      'e1e1e1e1-1111-4111-a111-111111111111',
      'Battle of Brain & Brawn',
      'balwaan'::event_category,
      'A thrilling physical challenge combined with rapid-fire literary puzzles. Race against the clock and show both your intelligence and strength!',
      '1. Teams must consist of exactly 2 members.\n2. Obstacles must be cleared sequentially.\n3. Anagram rounds are timed.',
      'College Amphitheatre',
      (CURRENT_DATE + INTERVAL '5 days')::date,
      '10:00:00',
      'https://images.unsplash.com/photo-1517649763962-0c623066013b',
      30,
      2,
      true,
      (NOW() + INTERVAL '4 days')::timestamptz,
      'registration_open'::event_status,
      v_admin_id,
      NOW(),
      NOW()
    ),
    (
      'e1e1e1e1-2222-4222-a222-222222222222',
      'Lit-Quiz 2026',
      'buddhimaan'::event_category,
      'The ultimate trivia challenge covering world literature, general knowledge, pop culture, and mythology.',
      '1. Individual participation only.\n2. Preliminary written round of 30 questions.\n3. Top 6 qualify for the stage finals.',
      'Library Seminar Hall',
      (CURRENT_DATE + INTERVAL '2 days')::date,
      '14:00:00',
      'https://images.unsplash.com/photo-1516979187457-637abb4f9353',
      100,
      1,
      false,
      (NOW() + INTERVAL '1 days')::timestamptz,
      'registration_open'::event_status,
      v_admin_id,
      NOW(),
      NOW()
    ),
    (
      'e1e1e1e1-3333-4333-a333-333333333333',
      'Turncoat Debate Championship',
      'darpan'::event_category,
      'Speak for and against the motion! Convince the judges in 3 minutes of sheer eloquence, logic, and poise.',
      '1. Individual participation.\n2. Topics will be given on the spot.\n3. 1 minute prep time, 3 minutes speaking time (1.5 for, 1.5 against).',
      'Mechanical Seminar Hall',
      (CURRENT_DATE + INTERVAL '3 days')::date,
      '11:00:00',
      'https://images.unsplash.com/photo-1524178232363-1fb2b075b655',
      40,
      1,
      false,
      (NOW() + INTERVAL '2 days')::timestamptz,
      'registration_open'::event_status,
      v_admin_id,
      NOW(),
      NOW()
    ),
    (
      'e1e1e1e1-4444-4444-a444-444444444444',
      'Brush & Quill',
      'kalakruthi'::event_category,
      'Paint a scene based on a prompt poem, or write a poem inspired by a painting. Merging the visual and literary arts.',
      '1. Individual participation.\n2. Materials like sheets and canvas will be provided.\n3. Duration: 2 hours.',
      'Drawing Hall 3',
      (CURRENT_DATE + INTERVAL '7 days')::date,
      '09:30:00',
      'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b',
      50,
      1,
      false,
      (NOW() + INTERVAL '6 days')::timestamptz,
      'draft'::event_status,
      v_admin_id,
      NOW(),
      NOW()
    )
  ON CONFLICT (id) DO UPDATE
  SET name = EXCLUDED.name,
      description = EXCLUDED.description,
      venue = EXCLUDED.venue,
      event_date = EXCLUDED.event_date;

  -- 5. Seed Demo Registrations
  -- Aditya (Student 1) -> Lit-Quiz (Event 2) & Turncoat (Event 3)
  INSERT INTO public.registrations (id, event_id, student_id, registration_method, registered_by, registered_at)
  VALUES 
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a101', 'e1e1e1e1-2222-4222-a222-222222222222', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b1', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '1 hours'),
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a102', 'e1e1e1e1-3333-4333-a333-333333333333', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b1', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '1 hours')
  ON CONFLICT (event_id, student_id) DO NOTHING;

  -- Riya (Student 2) -> Lit-Quiz (Event 2)
  INSERT INTO public.registrations (id, event_id, student_id, registration_method, registered_by, registered_at)
  VALUES 
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a103', 'e1e1e1e1-2222-4222-a222-222222222222', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b2', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '45 minutes')
  ON CONFLICT (event_id, student_id) DO NOTHING;

  -- Rohan (Student 3) -> Turncoat (Event 3)
  INSERT INTO public.registrations (id, event_id, student_id, registration_method, registered_by, registered_at)
  VALUES 
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a104', 'e1e1e1e1-3333-4333-a333-333333333333', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b3', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '30 minutes')
  ON CONFLICT (event_id, student_id) DO NOTHING;

  -- Sneha (Student 4) -> Lit-Quiz (Event 2) & Turncoat (Event 3)
  INSERT INTO public.registrations (id, event_id, student_id, registration_method, registered_by, registered_at)
  VALUES 
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a105', 'e1e1e1e1-2222-4222-a222-222222222222', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b4', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '15 minutes'),
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a106', 'e1e1e1e1-3333-4333-a333-333333333333', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b4', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '15 minutes')
  ON CONFLICT (event_id, student_id) DO NOTHING;

  -- Vikram (Student 5) -> Lit-Quiz (Event 2)
  INSERT INTO public.registrations (id, event_id, student_id, registration_method, registered_by, registered_at)
  VALUES 
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a107', 'e1e1e1e1-2222-4222-a222-222222222222', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b5', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '5 minutes')
  ON CONFLICT (event_id, student_id) DO NOTHING;

  -- Manoj (Student 9) -> Lit-Quiz (Event 2)
  INSERT INTO public.registrations (id, event_id, student_id, registration_method, registered_by, registered_at)
  VALUES 
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a108', 'e1e1e1e1-2222-4222-a222-222222222222', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1b9', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '2 minutes')
  ON CONFLICT (event_id, student_id) DO NOTHING;

  -- Divya (Student 10) -> Turncoat (Event 3)
  INSERT INTO public.registrations (id, event_id, student_id, registration_method, registered_by, registered_at)
  VALUES 
    ('r1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a109', 'e1e1e1e1-3333-4333-a333-333333333333', 'a1b1c1d1-e1f1-41a1-81b1-c1d1e1f1a1c0', 'manual'::registration_method, v_admin_id, NOW() - INTERVAL '1 minutes')
  ON CONFLICT (event_id, student_id) DO NOTHING;

  RAISE NOTICE 'Demo data seeding completed successfully!';
END $$;
