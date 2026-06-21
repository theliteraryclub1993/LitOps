-- Migration: Add missing roles to user_role enum to match UserRole Dart enum definition
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'creative_director';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'designer_in_chief';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'treasurer';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'co_treasurer_social_media';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'editorial_head';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'event_manager_co_editorial';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'creative_head';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'digital_head';
