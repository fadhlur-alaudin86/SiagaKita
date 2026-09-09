-- Rollback for 012_reports_and_volunteer.up.sql

ALTER TABLE public.user_profiles
    DROP COLUMN IF EXISTS volunteer_experience;

ALTER TABLE public.incident_reports
    ALTER COLUMN status SET DEFAULT 'received';

ALTER TABLE public.incident_reports
    ALTER COLUMN urgency_level SET NOT NULL;
