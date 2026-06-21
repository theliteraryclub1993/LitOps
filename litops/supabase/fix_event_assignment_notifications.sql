-- ============================================================================
-- LitOps: Fix Event Assignment Notification System
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New Query > Run)
-- ============================================================================
-- 
-- WHAT THIS FIXES:
-- The trigger function handle_new_crew_assignment() was querying events.name
-- but the actual column is events.title, causing the trigger to fail with error 42703.
-- As a result, NO notification was ever inserted when an event was assigned.
--
-- WHAT THIS ADDS:
-- 1. sender_user_id and type columns on the notifications table
-- 2. Fixed trigger that uses the correct column name and includes admin name
-- 3. Unassignment trigger so users are notified when removed from an event
-- ============================================================================

-- ============================================================================
-- STEP 1: Add new columns to the notifications table
-- ============================================================================

-- sender_user_id: who triggered the notification (e.g. the admin who assigned)
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS sender_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- type: categorize notifications (event_assignment, event_unassignment, general, etc.)
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'general';

-- Index for efficient lookups by type
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);

-- Index for lookups by sender
CREATE INDEX IF NOT EXISTS idx_notifications_sender ON public.notifications(sender_user_id);

-- ============================================================================
-- STEP 2: Fix the crew assignment notification trigger
-- ============================================================================

-- Drop the old trigger first
DROP TRIGGER IF EXISTS on_crew_assigned ON public.event_assignments;

-- Recreate the function with the CORRECT column name and improved message
CREATE OR REPLACE FUNCTION public.handle_new_crew_assignment()
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
        NEW.user_id,                -- recipient = the assigned user
        NEW.assigned_by,            -- sender = the admin who assigned
        'New Event Assignment',
        'You have been assigned to the event "' || COALESCE(v_event_name, 'Unknown Event') || '" by ' || COALESCE(v_admin_name, 'an administrator') || '.',
        'event_assignment',
        NEW.event_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER on_crew_assigned
    AFTER INSERT ON public.event_assignments
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_crew_assignment();

-- ============================================================================
-- STEP 3: Create unassignment notification trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_crew_unassignment()
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
        OLD.user_id,                -- recipient = the user who was removed
        'Assignment Removed',
        'You have been removed from the event "' || COALESCE(v_event_name, 'Unknown Event') || '".',
        'event_unassignment',
        OLD.event_id
    );

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger for DELETE on event_assignments
DROP TRIGGER IF EXISTS on_crew_unassigned ON public.event_assignments;
CREATE TRIGGER on_crew_unassigned
    AFTER DELETE ON public.event_assignments
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_crew_unassignment();

-- ============================================================================
-- STEP 4: Verify setup
-- ============================================================================

-- Show all triggers on event_assignments to confirm both are active
SELECT
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'event_assignments'
ORDER BY trigger_name;

-- Show notification table columns to confirm new columns exist
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'notifications'
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Confirmation
SELECT 'Event assignment notification system fixed successfully!' AS status;
