-- Rollback for 010_admin_features.up.sql

DROP INDEX IF EXISTS public.idx_users_last_active;

ALTER TABLE public.users
    DROP COLUMN IF EXISTS last_active_at;
