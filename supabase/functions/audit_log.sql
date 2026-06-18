/* Supabase Edge Function: audit_log.sql */
-- This function logs admin actions into the audit_logs table.
-- It expects JSON payload with fields: user_id (uuid), action (text), details (jsonb).
CREATE OR REPLACE FUNCTION public.log_admin_action(payload jsonb)
RETURNS void AS $$
BEGIN
  INSERT INTO public.audit_logs (user_id, action, details, logged_at)
  VALUES (
    payload->>'user_id'::uuid,
    payload->>'action',
    payload->'details',
    now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- To call this function from Supabase client:
-- const { data, error } = await supabase.rpc('log_admin_action', { payload: { user_id: user.id, action: 'update_member', details: { memberId: id, changes: changes } } });
