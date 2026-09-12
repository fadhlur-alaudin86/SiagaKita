-- Rollback 023: Remove fcm_token index and column from user_profiles
DROP INDEX IF EXISTS public.idx_up_fcm_token;

ALTER TABLE public.user_profiles
DROP COLUMN IF EXISTS fcm_token;
