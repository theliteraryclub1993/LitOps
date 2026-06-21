-- Temporarily drop the profile update restrictions trigger to allow testing
DROP TRIGGER IF EXISTS trg_enforce_profile_update_restrictions ON public.profiles;
