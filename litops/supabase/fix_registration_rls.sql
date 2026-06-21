-- Allow any authenticated user to create registrations
DROP POLICY IF EXISTS "Authorized roles can create registrations" ON registrations;
CREATE POLICY "Authorized roles can create registrations" ON registrations FOR INSERT TO authenticated WITH CHECK (true);

-- Allow any authenticated user to create and manage teams
DROP POLICY IF EXISTS "Authorized roles can manage teams" ON teams;
CREATE POLICY "Authorized roles can manage teams" ON teams FOR ALL TO authenticated USING (true);

-- Allow any authenticated user to manage team members
DROP POLICY IF EXISTS "Authorized roles can manage team members" ON team_members;
CREATE POLICY "Authorized roles can manage team members" ON team_members FOR ALL TO authenticated USING (true);
