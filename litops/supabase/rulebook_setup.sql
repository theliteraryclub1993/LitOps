-- 1. Create the rulebook table to store metadata
CREATE TABLE IF NOT EXISTS public.rulebook (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_url TEXT NOT NULL,
  uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create the overwrite trigger function to maintain only one active rulebook
CREATE OR REPLACE FUNCTION public.replace_old_rulebook()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.rulebook WHERE id IS NOT NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_replace_old_rulebook ON public.rulebook;
CREATE TRIGGER trg_replace_old_rulebook
BEFORE INSERT ON public.rulebook
FOR EACH ROW
EXECUTE FUNCTION public.replace_old_rulebook();

-- 3. Create rulebook bucket in storage if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('rulebooks', 'rulebooks', true, 209715200, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE
SET file_size_limit = 209715200,
    allowed_mime_types = ARRAY['application/pdf'];

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.rulebook ENABLE ROW LEVEL SECURITY;

-- 5. Set up RLS Policies for rulebook table
DROP POLICY IF EXISTS "Anyone can view active rulebook" ON public.rulebook;
CREATE POLICY "Anyone can view active rulebook" ON public.rulebook
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Super admins can manage rulebook metadata" ON public.rulebook;
DROP POLICY IF EXISTS "Admins can manage rulebook metadata" ON public.rulebook;
DROP POLICY IF EXISTS "Admins can manage rulebook metadata" ON public.rulebook;
CREATE POLICY "Admins can manage rulebook metadata" ON public.rulebook
  FOR ALL TO authenticated USING (public.is_admin());

-- 6. Set up RLS Policies for rulebooks storage bucket
DROP POLICY IF EXISTS "Public Read Access for Rulebooks" ON storage.objects;
CREATE POLICY "Public Read Access for Rulebooks" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'rulebooks');

DROP POLICY IF EXISTS "Admins can upload rulebooks" ON storage.objects;
CREATE POLICY "Admins can upload rulebooks" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'rulebooks' AND public.is_admin());

DROP POLICY IF EXISTS "Admins can update rulebooks" ON storage.objects;
CREATE POLICY "Admins can update rulebooks" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'rulebooks' AND public.is_admin());

DROP POLICY IF EXISTS "Admins can delete rulebooks" ON storage.objects;
CREATE POLICY "Admins can delete rulebooks" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'rulebooks' AND public.is_admin());

-- 7. Relax RLS policies for registration & scanning for junior wing users
-- Update registrations policy
DROP POLICY IF EXISTS "Authorized roles can create registrations" ON public.registrations;
CREATE POLICY "Authorized roles can create registrations" ON public.registrations
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND is_active = true
    )
  );

-- Update teams policy
DROP POLICY IF EXISTS "Authorized roles can manage teams" ON public.teams;
CREATE POLICY "Authorized roles can manage teams" ON public.teams
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND is_active = true
    )
  );

-- Update team_members policy
DROP POLICY IF EXISTS "Authorized roles can manage team members" ON public.team_members;
CREATE POLICY "Authorized roles can manage team members" ON public.team_members
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND is_active = true
    )
  );

-- Update student_master policy
DROP POLICY IF EXISTS "Authorized roles can insert students" ON public.student_master;
CREATE POLICY "Authorized roles can insert students" ON public.student_master
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND is_active = true
    )
  );

DROP POLICY IF EXISTS "Authorized roles can update students" ON public.student_master;
CREATE POLICY "Authorized roles can update students" ON public.student_master
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND is_active = true
    )
  );

-- 8. Enable Realtime updates
DO $$
DECLARE
  tables text[] := ARRAY['profiles', 'rulebook'];
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY tables
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', table_name);
      RAISE NOTICE 'Added % to supabase_realtime publication', table_name;
    EXCEPTION
      WHEN duplicate_object THEN
        RAISE NOTICE '% is already in supabase_realtime publication', table_name;
    END;
  END LOOP;
END $$;

ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.rulebook REPLICA IDENTITY FULL;
