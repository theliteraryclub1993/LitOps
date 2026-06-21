-- ============================================================================
-- LitOps FCM Tokens & Push Notification Trigger
-- Run this in the Supabase SQL Editor
-- ============================================================================

-- 0. Enable pg_net extension (required for http_post)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 1. Create the user_fcm_tokens table
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    fcm_token TEXT UNIQUE NOT NULL,
    device_type TEXT CHECK (device_type IN ('android', 'ios')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Enable RLS on user_fcm_tokens
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS Policies for user_fcm_tokens
DROP POLICY IF EXISTS "Users can read own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can read own FCM tokens" ON public.user_fcm_tokens
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can insert own FCM tokens" ON public.user_fcm_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can update own FCM tokens" ON public.user_fcm_tokens
    FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can delete own FCM tokens" ON public.user_fcm_tokens
    FOR DELETE USING (auth.uid() = user_id);

-- 4. Create trigger function to call the send-push Edge Function
CREATE OR REPLACE FUNCTION public.handle_new_notification_trigger()
RETURNS TRIGGER AS $$
DECLARE
    project_ref TEXT := 'gqmyqrnbmutxhjjelhhb'; -- Supabase project ID
BEGIN
    -- Invoke the Edge Function asynchronously via the pg_net extension
    PERFORM net.http_post(
        url := 'https://' || project_ref || '.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            -- Edge functions are authorized via the anon key by default
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI'
        ),
        body := jsonb_build_object(
            'record', row_to_json(NEW)
        ),
        timeout_milliseconds := 5000
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Create the database trigger
DROP TRIGGER IF EXISTS on_notification_created ON public.notifications;
CREATE TRIGGER on_notification_created
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_notification_trigger();
