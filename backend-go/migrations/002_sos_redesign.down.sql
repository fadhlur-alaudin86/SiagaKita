-- Rollback for 002_sos_redesign.up.sql

ALTER TABLE public.incidents
    DROP COLUMN IF EXISTS urgency_level,
    DROP COLUMN IF EXISTS reporter_trust_label;

ALTER TABLE public.users
    DROP COLUMN IF EXISTS banned_until,
    DROP COLUMN IF EXISTS is_sos_banned,
    DROP COLUMN IF EXISTS sos_strike_count;

DROP TABLE IF EXISTS public.sos_strikes CASCADE;
DROP TABLE IF EXISTS public.incident_reports CASCADE;
DROP TYPE IF EXISTS public.urgency_level CASCADE;
