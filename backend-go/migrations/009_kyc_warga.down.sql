-- Rollback for 009_kyc_warga.up.sql

ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS chk_nik_status;

ALTER TABLE public.user_profiles
    DROP COLUMN IF EXISTS nik_verification_status,
    DROP COLUMN IF EXISTS profile_photo_url,
    DROP COLUMN IF EXISTS kyc_ktp_url;
