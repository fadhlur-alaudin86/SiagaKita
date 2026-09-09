-- Rollback for 011_drop_phone_unique.up.sql

ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_phone_number_key UNIQUE (phone_number);
