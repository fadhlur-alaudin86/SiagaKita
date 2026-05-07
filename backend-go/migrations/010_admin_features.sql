-- Migration 010: Admin Features
-- Menambahkan last_active_at untuk tracking status online pengguna warga

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS last_active_at timestamptz;

-- Index untuk query status online
CREATE INDEX IF NOT EXISTS idx_users_last_active ON public.users(last_active_at);

DO $$ BEGIN
    RAISE NOTICE 'Migration 010 berhasil: last_active_at ditambahkan ke tabel users';
END $$;
