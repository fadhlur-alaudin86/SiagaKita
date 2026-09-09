-- Rollback for 016_place_of_birth.up.sql

ALTER TABLE public.user_profiles
    DROP COLUMN IF EXISTS place_of_birth;
