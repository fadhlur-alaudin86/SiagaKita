-- Migration 010: Hapus constraint UNIQUE pada phone_number di user_profiles
-- Alasan: nomor HP yang sama bisa digunakan oleh lebih dari satu akun (mis. keluarga).
-- NIK tetap UNIQUE karena 1 KTP = 1 orang.

ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_phone_number_key;
