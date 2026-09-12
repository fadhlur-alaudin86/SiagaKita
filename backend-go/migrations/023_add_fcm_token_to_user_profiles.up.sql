-- Migration 023: Add fcm_token to user_profiles for push notification delivery
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Create partial index for fast lookup of active FCM device tokens
CREATE INDEX IF NOT EXISTS idx_up_fcm_token
ON public.user_profiles(fcm_token)
WHERE fcm_token IS NOT NULL;
