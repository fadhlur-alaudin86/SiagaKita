-- Rollback for 008_incident_enhancements.up.sql

ALTER TABLE public.incidents
    DROP COLUMN IF EXISTS audio_path,
    DROP COLUMN IF EXISTS photo_paths,
    ADD COLUMN IF NOT EXISTS trigger_method varchar(20) NOT NULL DEFAULT 'timeout';
-- Note: PostgreSQL does not support removing 'canceled' value from enum incident_status directly.
