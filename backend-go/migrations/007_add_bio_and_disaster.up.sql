-- ============================================================
-- SIAGAKITA — Migration 007: Add bio to user_profiles & disaster to incident_category
-- Jalankan manual:
--   sudo docker exec -i siagakita_postgres psql -U siagakita_admin -d siagakita < backend-go/migrations/007_add_bio_and_disaster.sql
-- ============================================================

-- 1. Tambah kolom 'bio' ke tabel user_profiles (jika belum ada)
ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS bio text;

-- 2. Tambah nilai 'disaster' ke enum incident_category (jika belum ada)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'disaster'
          AND enumtypid = 'public.incident_category'::regtype
    ) THEN
        ALTER TYPE public.incident_category ADD VALUE 'disaster';
    END IF;
END;
$$;

SELECT 'Migration 007 berhasil dijalankan.' AS status;
