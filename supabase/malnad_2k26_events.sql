-- =============================================================================
-- MALNAD 2K26 Events Import Script for LitOps
-- Categories: BALWAAN, BUDDHIMAAN, DARPAN, KALAKRUTHI
-- =============================================================================
-- NOTE: Run this in your Supabase SQL Editor.
-- The `created_by` field is auto-filled from your super admin profile.
-- =============================================================================

-- STEP 1: Insert all MALNAD 2K26 events
-- =============================================================================

WITH inserted_events AS (
  INSERT INTO events (title, category, description, rules, team_size, is_team_event, status, created_by)
  VALUES

    -- ──────────────────────────────────────────────────────────────────────────
    -- BALWAAN
    -- ──────────────────────────────────────────────────────────────────────────
    (
      'Desafio', 'balwaan',
      'Physical fitness challenge. Best timing wins.',
      E'- Physical fitness challenge.\n- Multiple tasks assigned.\n- Tasks must be completed in proper form.\n- Best timing wins.\n\nConstraints:\n- 1 male participant per branch.',
      1, false, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Game On!', 'balwaan',
      'Multiplayer PC and mobile gaming event. Participants bring their own devices.',
      E'- No third-party software/tools.\n- Participants bring their own devices.\n\nSub-events:\n- BGMI: Team of 4\n- FIFA: Solo\n- SmashKarts.io',
      4, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Malnad Hudgir Halli Lifeu', 'balwaan',
      'Series of physical tasks. Best timing wins.',
      E'- Series of physical tasks.\n- Best timing wins.\n\nConstraints:\n- 1 female participant per branch.',
      1, false, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Pentathlon', 'balwaan',
      'Includes Cycling, Skipping, Obstacle Course, Swimming and Running. Each participant performs one task.',
      E'- Includes Cycling, Skipping, Obstacle Course, Swimming and Running.\n- Each participant performs one task.\n\nConstraints:\n- Team size: 5\n- 1 team per branch.',
      5, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Scavenger Hunt', 'balwaan',
      'Conducted within campus. No vehicles or mobile phones allowed.',
      E'- Conducted within campus.\n- No vehicles.\n- No mobile phones.\n\nConstraints:\n- Team size: 3\n- 1 team per branch.',
      3, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Tug Of War', 'balwaan',
      'Classic tug of war. Shoes mandatory. Minimum 2 girls required per team.',
      E'- Rope must remain below arms.\n- Shoes mandatory.\n- Team members must remain standing.\n\nConstraints:\n- Team size: 8\n- Minimum girls required: 2\n- Maximum team weight: 640 kg\n- 1 team per branch.',
      8, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      '90''s Kids', 'balwaan',
      'Nostalgic games from the 90s: Pen Fight, Chowka Bara, Lagori, Goli.',
      E'Sub-events:\n- Pen Fight\n- Chowka Bara\n- Lagori\n- Goli\n\nConstraints:\n- 1 participant per branch.',
      1, false, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),

    -- ──────────────────────────────────────────────────────────────────────────
    -- BUDDHIMAAN
    -- ──────────────────────────────────────────────────────────────────────────
    (
      'Dumb Charades', 'buddhimaan',
      'Classic mime-based word guessing game. No lip movement, no pointing, no lettering.',
      E'- Mime only.\n- No lip movement.\n- No pointing.\n- No lettering.\n\nConstraints:\n- Team size: 3\n- 1 team per branch.',
      3, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Khichdi', 'buddhimaan',
      'Faculty-only event combining Dumb Charades, Antakshari and Pictionary.',
      E'- Includes Dumb Charades, Antakshari and Pictionary.\n\nConstraints:\n- Team size: 2\n- 2 teams per branch\n- Faculty only.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Knock Out', 'buddhimaan',
      'Written prelims followed by knockout rounds. Team members separated during prelims. Top 5 qualify.',
      E'- Written prelims.\n- Team members separated during prelims.\n- Top 5 qualify.\n\nConstraints:\n- Team size: 2\n- 2 teams per branch.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Literati', 'buddhimaan',
      'Literature-based competition.',
      E'- Literature-based competition.\n\nConstraints:\n- Team size: 2\n- 1 team per branch.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'The Toastmaster', 'buddhimaan',
      'Individual public speaking and communication event with Group Discussion, JAM, Mock Press and Stress Interview rounds.',
      E'Rounds:\n- Group Discussion\n- JAM\n- Mock Press\n- Stress Interview\n\nConstraints:\n- 2 participants per branch.',
      1, false, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Maatina Malla', 'buddhimaan',
      'Kannada language event with Ulta Palta, Kannada Jenu and Suddhi Goshti rounds.',
      E'Rounds:\n- Ulta Palta\n- Kannada Jenu\n- Suddhi Goshti\n\nConstraints:\n- 1 participant per branch.',
      1, false, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Quiz', 'buddhimaan',
      'Written prelims. Top 4 teams qualify for the final rounds.',
      E'- Written prelims.\n- Top 4 qualify.\n\nConstraints:\n- Team size: 3\n- 2 teams per branch.',
      3, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Sherlokians', 'buddhimaan',
      'Case-solving detective event conducted within campus. No vehicles or mobile phones.',
      E'- Case-solving event.\n- No vehicles.\n- No mobile phones.\n- Conducted within campus.\n\nConstraints:\n- Team size: 2\n- 1 team per branch.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Spell Bee', 'buddhimaan',
      'Spell words letter-by-letter. Test your vocabulary and spelling!',
      E'- Spell words letter-by-letter.\n\nConstraints:\n- 2 participants per branch.',
      1, false, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'TDH', 'buddhimaan',
      'Written prelims. Top 4 teams qualify for the final rounds.',
      E'- Written prelims.\n- Top 4 qualify.\n\nConstraints:\n- Team size: 2\n- 2 teams per branch.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),

    -- ──────────────────────────────────────────────────────────────────────────
    -- DARPAN
    -- ──────────────────────────────────────────────────────────────────────────
    (
      'Antakshari (Hindi)', 'darpan',
      'Hindi Antakshari competition.',
      E'Constraints:\n- Team size: 2\n- 2 teams per branch.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Antakshari (Kannada)', 'darpan',
      'Kannada Antakshari competition.',
      E'Constraints:\n- Team size: 2\n- 2 teams per branch.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Campus Beats', 'darpan',
      'Video must be shot inside campus. Max 2 minutes duration.',
      E'- Video must be shot inside campus.\n\nConstraints:\n- Team size: 6–8\n- 1 team per branch\n- Video length: Max 2 minutes.',
      6, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Naa Kanda Malnad', 'darpan',
      'Video submission event. Language: English/Hindi/Kannada. Duration: 4+1 minutes.',
      E'- Language: English/Hindi/Kannada.\n- Video length: 4+1 minutes.\n\nConstraints:\n- Max participants: 10.',
      10, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'No Budget Parody', 'darpan',
      'Recreate a movie trailer on a no-budget setup. Aspect ratio: 16:9. Original trailer must accompany submission.',
      E'- Recreate movie trailer.\n- Original trailer must accompany submission.\n- Aspect ratio: 16:9.\n\nConstraints:\n- Max participants: 10.',
      10, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Sonance', 'darpan',
      'Instrumental music event. No lyrics allowed. Duration: 45 sec – 2 minutes.',
      E'- Instrumental only.\n- No lyrics allowed.\n\nConstraints:\n- Team size: 3–5\n- Video length: 45 sec – 2 min.',
      3, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Sync The Scene', 'darpan',
      'Storytelling through songs. No captions. Max 2 minutes.',
      E'- Storytelling through songs.\n- No captions.\n\nConstraints:\n- Team size: 6\n- Video length: Max 2 min.',
      6, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'The Director''s Edit', 'darpan',
      'Short film competition. Duration: 3+1 minutes. Max 10 participants.',
      E'Constraints:\n- Max participants: 10\n- Video length: 3+1 mins.',
      10, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Aarambh Se Anth', 'darpan',
      'Stage performance event. Props allowed. Duration: 4+1 minutes.',
      E'- Props allowed.\n\nConstraints:\n- Team size: 10–15\n- Performance: 4+1 mins.',
      10, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Dance To The Tune', 'darpan',
      'Fusion dance competition. No props. Team size: 6–10.',
      E'- Fusion dance.\n- No props.\n\nConstraints:\n- Team size: 6–10.',
      6, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Duet Singing', 'darpan',
      'Duet vocal performance. Maximum one instrument. Karaoke allowed. Duration: 3 minutes.',
      E'- Maximum one instrument.\n- Karaoke allowed.\n\nConstraints:\n- Team size: 2\n- Performance: 3 mins.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Flash Mob', 'darpan',
      'Flash mob performance. Mascot compulsory. Handmade props allowed. Duration: 6 minutes.',
      E'- Mascot compulsory.\n- Handmade props allowed.\n\nConstraints:\n- Team size: 15–20\n- Performance: 6 mins.',
      15, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Takadhimita', 'darpan',
      'Dance styles assigned by organizers. No props. Duration: 4+1 minutes.',
      E'- Dance styles assigned by organizers.\n- No props.\n\nConstraints:\n- Team size: 9–12\n- Performance: 4+1 mins.',
      9, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Tribute Dance', 'darpan',
      'Theme provided before event. Props allowed. Duration: 4+1 minutes.',
      E'- Theme provided before event.\n- Props allowed.\n\nConstraints:\n- Team size: 6–10\n- Performance: 4+1 mins.',
      6, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'UV Footloose', 'darpan',
      'UV lights provided by organizers. Duration: 4 minutes.',
      E'- UV lights provided by organizers.\n\nConstraints:\n- Team size: 6–10\n- Performance: 4 mins.',
      6, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Vogue', 'darpan',
      'Fashion show event. Duration: 6+1 minutes.',
      E'- Fashion show.\n\nConstraints:\n- Team size: 10–14\n- Performance: 6+1 mins.',
      10, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Y2K Rewind', 'darpan',
      'Theme announced before event. Duration: 4+1 minutes.',
      E'- Theme announced before event.\n\nConstraints:\n- Team size: 8–10\n- Performance: 4+1 mins.',
      8, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),

    -- ──────────────────────────────────────────────────────────────────────────
    -- KALAKRUTHI
    -- ──────────────────────────────────────────────────────────────────────────
    (
      'Art-A-Thon', 'kalakruthi',
      'Relay-style art event. Theme announced on spot. Only 3 sheets provided. 30 minutes per participant.',
      E'- Theme announced on spot.\n- Only 3 sheets provided.\n- Participants bring remaining materials.\n- Judged on creativity, imagination and synergy.\n\nConstraints:\n- Team size: 3\n- 1 team per branch\n- Total duration: 90 minutes.',
      3, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Chitrakatha', 'kalakruthi',
      'One participant draws, the other writes a story based on the drawings. Theme announced on spot.',
      E'- Theme announced on spot.\n- One participant draws.\n- Other participant writes story.\n- Story must be based on drawings.\n- No lettering allowed in drawings.\n- Judged on story and depiction.\n\nConstraints:\n- Team size: 2\n- 1 team per branch\n- Sketching time: 60 minutes\n- Story writing time: 10 minutes\n- Maximum 5 pictures.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Graffiti', 'kalakruthi',
      'Spray-art on campus walls. Theme announced before event. Paint brushes not allowed.',
      E'- Theme announced before event.\n- Participants bring spray cans, stencils and accessories.\n- Paint brushes not allowed.\n- No additional supplies after start.\n- Artwork must stay within allocated wall space.\n- No political, religious or controversial artwork.\n- No pornographic artwork.\n\nConstraints:\n- Team size: 4\n- 1 team per branch\n- Duration: 120 minutes.',
      4, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Ink The Tee', 'kalakruthi',
      'Paint a white T-shirt with acrylic paint. Submission deadline: April 30, 2026.',
      E'- White T-shirt provided.\n- Only acrylic paint allowed.\n- Judging based on T-shirt and submitted timelapse.\n- Submission deadline: April 30, 2026.\n\nConstraints:\n- Team size: 2\n- 1 team per branch.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Pot Painting', 'kalakruthi',
      'Paint a pot provided by organizers. Theme announced before event. Stencils not allowed.',
      E'- Theme announced before event.\n- Pots provided by organizers.\n- Stencils not allowed.\n- Participants cannot leave venue during event.\n- Participants bring required materials.\n- No external materials after start.\n- Judged on creativity and color contrast.\n\nConstraints:\n- 1 participant per branch\n- Duration: 90 minutes.',
      1, false, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Sculptopia', 'kalakruthi',
      'Clay sculpture event. Theme announced before event. Clay provided by organizers. No clay molds.',
      E'- Theme announced before event.\n- Clay provided by organizers.\n- No clay molds allowed.\n- Participants bring clay modeling tools.\n- Judged on creativity, neatness, finishing and specificity.\n\nConstraints:\n- Team size: 2\n- 1 team per branch\n- Duration: 90 minutes.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    ),
    (
      'Tattooing', 'kalakruthi',
      'Draw a tattoo on the upper arm using black marker. Theme announced on spot. Only black color allowed.',
      E'- Theme announced on spot.\n- Tattoo must be drawn only on upper arm.\n- Only black color allowed.\n- Participants bring black marker/OHP pen.\n- Judged on creativity, appearance and design.\n\nConstraints:\n- Team size: 2\n- 1 team per branch\n- Duration: 90 minutes.',
      2, true, 'upcoming',
      (SELECT id FROM profiles WHERE role = 'super_admin' LIMIT 1)
    )

  RETURNING id, title
),

-- =============================================================================
-- STEP 2: Build all constraints from the inserted events
-- Branches: CSE, EEE, ISE, EI, ECE, VLSI, Mechanical, RAI, AIML, CSBS, Civil
-- =============================================================================

all_branches(branch) AS (
  SELECT unnest(ARRAY['CSE', 'EEE', 'ISE', 'EI', 'ECE', 'VLSI', 'Mechanical', 'RAI', 'AIML', 'CSBS', 'Civil'])
),

-- Events where max 1 registration per branch (individual or 1 team per branch)
single_per_branch AS (
  SELECT ie.id AS event_id, ab.branch, 1 AS max_participants
  FROM inserted_events ie
  CROSS JOIN all_branches ab
  WHERE ie.title IN (
    'Desafio', 'Malnad Hudgir Halli Lifeu', '90''s Kids',
    'Pentathlon', 'Scavenger Hunt', 'Tug Of War', 'Game On!',
    'Dumb Charades', 'Literati', 'Maatina Malla', 'Sherlokians',
    'Campus Beats', 'Sonance', 'Sync The Scene', 'Aarambh Se Anth',
    'Dance To The Tune', 'Duet Singing', 'Flash Mob', 'Takadhimita',
    'Tribute Dance', 'UV Footloose', 'Vogue', 'Y2K Rewind',
    'Naa Kanda Malnad', 'No Budget Parody', 'The Director''s Edit',
    'Art-A-Thon', 'Chitrakatha', 'Graffiti', 'Ink The Tee',
    'Pot Painting', 'Sculptopia', 'Tattooing'
  )
),

-- Events where max 2 registrations per branch (2 teams or 2 individuals per branch)
double_per_branch AS (
  SELECT ie.id AS event_id, ab.branch, 2 AS max_participants
  FROM inserted_events ie
  CROSS JOIN all_branches ab
  WHERE ie.title IN (
    'Khichdi', 'Knock Out', 'Quiz', 'TDH',
    'The Toastmaster', 'Spell Bee',
    'Antakshari (Hindi)', 'Antakshari (Kannada)'
  )
),

all_constraints AS (
  SELECT * FROM single_per_branch
  UNION ALL
  SELECT * FROM double_per_branch
)

INSERT INTO participation_constraints (event_id, branch, max_participants)
SELECT event_id, branch, max_participants FROM all_constraints;

-- =============================================================================
-- STEP 3: Branch event limits (stored as a comment for reference)
-- Apply these as application-level rules:
-- CSE: max 3 events
-- EEE, ISE, EI, ECE, VLSI, Mechanical, RAI: max 6 events
-- AIML, CSBS, Civil: max 7 events
-- =============================================================================

-- Confirmation
SELECT 
  category,
  COUNT(*) AS total_events
FROM events
WHERE title IN (
  'Desafio', 'Game On!', 'Malnad Hudgir Halli Lifeu', 'Pentathlon',
  'Scavenger Hunt', 'Tug Of War', '90''s Kids',
  'Dumb Charades', 'Khichdi', 'Knock Out', 'Literati', 'The Toastmaster',
  'Maatina Malla', 'Quiz', 'Sherlokians', 'Spell Bee', 'TDH',
  'Antakshari (Hindi)', 'Antakshari (Kannada)', 'Campus Beats',
  'Naa Kanda Malnad', 'No Budget Parody', 'Sonance', 'Sync The Scene',
  'The Director''s Edit', 'Aarambh Se Anth', 'Dance To The Tune',
  'Duet Singing', 'Flash Mob', 'Takadhimita', 'Tribute Dance',
  'UV Footloose', 'Vogue', 'Y2K Rewind',
  'Art-A-Thon', 'Chitrakatha', 'Graffiti', 'Ink The Tee',
  'Pot Painting', 'Sculptopia', 'Tattooing'
)
GROUP BY category
ORDER BY category;
