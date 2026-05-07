-- ============================================================
-- SIAGAKITA — Migration 008: Incident Enhancements
-- Perubahan:
--   1. Tambah nilai 'cancel' ke enum incident_status
--   2. Hapus kolom trigger_method dari tabel incidents (tidak diperlukan)
--   3. Tambah kolom photo_paths dan audio_path ke tabel incidents
--      (untuk menyimpan bukti situasi yang diambil otomatis pasca broadcasting)
--
-- Jalankan manual:
--   sudo docker exec -i siagakita_postgres psql -U siagakita_admin -d siagakita < backend-go/migrations/008_incident_enhancements.sql
-- ============================================================

-- 1. Tambah nilai 'cancel' ke enum incident_status
--    'cancel' = pembatalan OLEH USER (berbeda dari 'false_alarm' = ditandai oleh agency/admin)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'cancel'
          AND enumtypid = 'public.incident_status'::regtype
    ) THEN
        ALTER TYPE public.incident_status ADD VALUE 'cancel';
    END IF;
END;
$$;

-- 2. Hapus kolom trigger_method jika masih ada
ALTER TABLE public.incidents
    DROP COLUMN IF EXISTS trigger_method;

-- 3. Tambah kolom photo_paths (array URL foto bukti situasi SOS)
ALTER TABLE public.incidents
    ADD COLUMN IF NOT EXISTS photo_paths TEXT[] DEFAULT '{}';

-- 4. Tambah kolom audio_path (URL audio rekaman 5 detik bukti situasi SOS)
ALTER TABLE public.incidents
    ADD COLUMN IF NOT EXISTS audio_path TEXT;

SELECT 'Migration 008 berhasil dijalankan.' AS status;
