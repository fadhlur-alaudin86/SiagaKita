-- Rollback for 014_incident_responses_update.up.sql

ALTER TABLE public.incident_responses
    RENAME COLUMN completed_at TO arrived_at;

ALTER TABLE public.incident_responses
    ALTER COLUMN status SET DEFAULT 'accepted'::public.response_status;
