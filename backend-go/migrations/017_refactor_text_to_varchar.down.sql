-- Rollback for 017_refactor_text_to_varchar.up.sql

ALTER TABLE public.user_profiles ALTER COLUMN bio TYPE TEXT;
ALTER TABLE public.user_profiles ALTER COLUMN allergies TYPE TEXT;
ALTER TABLE public.user_profiles ALTER COLUMN medical_conditions TYPE TEXT;
ALTER TABLE public.user_profiles ALTER COLUMN domicile TYPE TEXT;
ALTER TABLE public.user_profiles ALTER COLUMN kyc_ktp_url TYPE TEXT;
ALTER TABLE public.user_profiles ALTER COLUMN profile_photo_url TYPE TEXT;
ALTER TABLE public.user_profiles ALTER COLUMN volunteer_experience TYPE TEXT;
ALTER TABLE public.incidents ALTER COLUMN audio_path TYPE TEXT;
ALTER TABLE public.incidents ALTER COLUMN address_detail TYPE TEXT;
ALTER TABLE public.incident_reports ALTER COLUMN description TYPE TEXT;
ALTER TABLE public.incident_reports ALTER COLUMN audio_path TYPE TEXT;
ALTER TABLE public.incident_responses ALTER COLUMN address_detail TYPE TEXT;
ALTER TABLE public.sos_strikes ALTER COLUMN reason TYPE TEXT;
ALTER TABLE public.m_badges ALTER COLUMN description TYPE TEXT;
