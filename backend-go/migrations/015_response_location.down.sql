-- Rollback for 015_response_location.up.sql

ALTER TABLE public.incident_responses
    DROP COLUMN IF EXISTS address_detail,
    DROP COLUMN IF EXISTS longitude,
    DROP COLUMN IF EXISTS latitude;
