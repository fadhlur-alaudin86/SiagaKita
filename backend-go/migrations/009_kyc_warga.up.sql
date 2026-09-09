-- Migration 009: KYC Warga (Civilian Identity Verification)
-- Versi 3: Menggunakan foto KTP untuk verifikasi, dan selfie sebagai foto profil.

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS kyc_ktp_url           text,
    ADD COLUMN IF NOT EXISTS profile_photo_url     text,
    ADD COLUMN IF NOT EXISTS nik_verification_status varchar(20) DEFAULT 'none';

-- Nilai valid: 'none' | 'pending' | 'approved' | 'rejected'
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_nik_status' AND conrelid = 'public.user_profiles'::regclass
    ) THEN
        ALTER TABLE public.user_profiles
            ADD CONSTRAINT chk_nik_status
                CHECK (nik_verification_status IN ('none', 'pending', 'approved', 'rejected'));
    END IF;
END $$;

DO $$ BEGIN
    RAISE NOTICE 'Migration 009 v3 berhasil dijalankan: kyc_ktp_url + profile_photo_url + nik_verification_status';
END $$;
