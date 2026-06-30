-- LitOps: App-wide settings (auth gates, maintenance messages)
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Anyone (including logged-out users) can read auth gate settings
DROP POLICY IF EXISTS "Public can read app settings" ON public.app_settings;
CREATE POLICY "Public can read app settings" ON public.app_settings
  FOR SELECT TO anon, authenticated USING (true);

-- Only super admin can change settings
DROP POLICY IF EXISTS "Super admin can manage app settings" ON public.app_settings;
CREATE POLICY "Super admin can manage app settings" ON public.app_settings
  FOR ALL TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- Defaults: sign-in and registration open
INSERT INTO public.app_settings (key, value) VALUES
  ('sign_in_enabled', 'true'),
  ('registration_enabled', 'true'),
  ('sign_in_disabled_message', 'Sign-in is temporarily disabled while we resolve authentication issues. Please try again later.')
ON CONFLICT (key) DO NOTHING;
