-- ============================================================================
-- LitOps Crew Assignment Notification Trigger
-- Run this in the Supabase SQL Editor
-- ============================================================================

-- 1. Create the trigger function to insert a notification
CREATE OR REPLACE FUNCTION public.handle_new_crew_assignment()
RETURNS TRIGGER AS $$
DECLARE
    event_name TEXT;
BEGIN
    -- Get the title of the event
    SELECT title INTO event_name 
    FROM public.events 
    WHERE id = NEW.event_id;

    -- Insert a notification for the newly assigned user
    INSERT INTO public.notifications (user_id, title, message, event_id)
    VALUES (
        NEW.user_id,
        'Event Assignment',
        'You have been assigned to the crew of the event: ' || COALESCE(event_name, 'Event'),
        NEW.event_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create the database trigger on public.event_assignments
DROP TRIGGER IF EXISTS on_crew_assigned ON public.event_assignments;
CREATE TRIGGER on_crew_assigned
    AFTER INSERT ON public.event_assignments
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_crew_assignment();
