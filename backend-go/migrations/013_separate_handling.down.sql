-- Rollback for 013_separate_handling.up.sql

DROP TABLE IF EXISTS public.volunteer_badges_acquired CASCADE;
DROP TABLE IF EXISTS public.m_badges CASCADE;

ALTER TABLE public.incident_responses
    DROP COLUMN IF EXISTS proof_photo_url;

ALTER TABLE public.incidents
    DROP COLUMN IF EXISTS agency_status,
    DROP COLUMN IF EXISTS handled_by_agency_id;
