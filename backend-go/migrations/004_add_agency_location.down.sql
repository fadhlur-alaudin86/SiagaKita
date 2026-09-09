-- Rollback for 004_add_agency_location.up.sql

ALTER TABLE public.agencies
    DROP COLUMN IF EXISTS latitude,
    DROP COLUMN IF EXISTS longitude;
