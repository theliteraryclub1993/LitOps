-- Fix: Both trigger functions reference events.name but the remote DB column is events.title
-- This causes PostgresException(code: 42703) "column name does not exist" when assigning crew

-- Fix assignment trigger
CREATE OR REPLACE FUNCTION handle_new_crew_assignment()
RETURNS TRIGGER AS $$
DECLARE
    v_event_name TEXT;
    v_admin_name TEXT;
BEGIN
    -- Get the event title (column is "title" in the remote events table)
    SELECT title INTO v_event_name
    FROM public.events
    WHERE id = NEW.event_id;

    -- Get the admin's full name who made the assignment
    SELECT full_name INTO v_admin_name
    FROM public.profiles
    WHERE id = NEW.assigned_by;

    -- Insert a notification for the ASSIGNED USER (NOT the admin)
    INSERT INTO public.notifications (
        user_id,
        sender_user_id,
        title,
        message,
        type,
        event_id
    )
    VALUES (
        NEW.user_id,
        NEW.assigned_by,
        'New Event Assignment',
        'You have been assigned to the event "' || COALESCE(v_event_name, 'Unknown Event') || '" by ' || COALESCE(v_admin_name, 'an administrator') || '.',
        'event_assignment',
        NEW.event_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix unassignment trigger
CREATE OR REPLACE FUNCTION handle_crew_unassignment()
RETURNS TRIGGER AS $$
DECLARE
    v_event_name TEXT;
BEGIN
    -- Get the event title
    SELECT title INTO v_event_name
    FROM public.events
    WHERE id = OLD.event_id;

    -- Insert a notification for the REMOVED USER
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        event_id
    )
    VALUES (
        OLD.user_id,
        'Assignment Removed',
        'You have been removed from the event "' || COALESCE(v_event_name, 'Unknown Event') || '".',
        'event_unassignment',
        OLD.event_id
    );

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- NOTE: event_assignments is already in supabase_realtime publication (confirmed)
