-- Rollback for 018_incident_reports_address_and_completed_at.up.sql

ALTER TABLE public.incident_reports
    DROP COLUMN IF EXISTS completed_at,
    DROP COLUMN IF EXISTS address_detail;
