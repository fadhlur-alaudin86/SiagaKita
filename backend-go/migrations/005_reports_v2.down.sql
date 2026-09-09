-- Rollback for 005_reports_v2.up.sql

DROP TABLE IF EXISTS public.incident_reports CASCADE;
ALTER TABLE IF EXISTS public.incident_reports_old RENAME TO incident_reports;
