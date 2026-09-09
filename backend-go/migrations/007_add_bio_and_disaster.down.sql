-- Rollback for 007_add_bio_and_disaster.up.sql

ALTER TABLE public.user_profiles
    DROP COLUMN IF EXISTS bio;
-- Note: PostgreSQL does not support removing 'disaster' value from enum incident_category directly.
