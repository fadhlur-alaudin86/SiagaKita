-- 016_refactor_text_to_varchar.sql

-- user_profiles
ALTER TABLE public.user_profiles ALTER COLUMN bio TYPE VARCHAR(255);
ALTER TABLE public.user_profiles ALTER COLUMN allergies TYPE VARCHAR(255);
ALTER TABLE public.user_profiles ALTER COLUMN medical_conditions TYPE VARCHAR(255);
ALTER TABLE public.user_profiles ALTER COLUMN domicile TYPE VARCHAR(255);
ALTER TABLE public.user_profiles ALTER COLUMN kyc_ktp_url TYPE VARCHAR(255);
ALTER TABLE public.user_profiles ALTER COLUMN profile_photo_url TYPE VARCHAR(255);
ALTER TABLE public.user_profiles ALTER COLUMN volunteer_experience TYPE VARCHAR(1000);

-- incidents
ALTER TABLE public.incidents ALTER COLUMN audio_path TYPE VARCHAR(255);
ALTER TABLE public.incidents ALTER COLUMN address_detail TYPE VARCHAR(500);

-- incident_reports
ALTER TABLE public.incident_reports ALTER COLUMN description TYPE VARCHAR(1000);
ALTER TABLE public.incident_reports ALTER COLUMN audio_path TYPE VARCHAR(255);

-- incident_responses
ALTER TABLE public.incident_responses ALTER COLUMN address_detail TYPE VARCHAR(255);

-- sos_strikes
ALTER TABLE public.sos_strikes ALTER COLUMN reason TYPE VARCHAR(500);

-- m_badges
ALTER TABLE public.m_badges ALTER COLUMN description TYPE VARCHAR(255);
