-- Migration 009: KYC Warga (Civilian Identity Verification)
-- Menambahkan kolom foto KTP, selfie, dan status verifikasi NIK ke user_profiles

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS kyc_ktp_url          text,
    ADD COLUMN IF NOT EXISTS kyc_selfie_url        text,
    ADD COLUMN IF NOT EXISTS nik_verification_status varchar(20) DEFAULT 'none';

-- Nilai valid: 'none' | 'pending' | 'approved' | 'rejected'
ALTER TABLE public.user_profiles
    ADD CONSTRAINT chk_nik_status
        CHECK (nik_verification_status IN ('none', 'pending', 'approved', 'rejected'));

DO $$ BEGIN
    RAISE NOTICE 'Migration 009 berhasil dijalankan.';
END $$;
