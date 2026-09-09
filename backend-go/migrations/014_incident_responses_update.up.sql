-- ============================================================
-- SIAGAKITA — Migration 013: Incident Responses Update
-- Perubahan:
--   1. RENAME COLUMN arrived_at TO completed_at pada incident_responses
--   2. Tambah nilai 'on_scene' ke enum response_status (jika belum ada)
--   3. Ubah default status pada incident_responses menjadi 'on_scene'
-- ============================================================

-- 1. Rename column
ALTER TABLE public.incident_responses
    RENAME COLUMN arrived_at TO completed_at;

-- 2. Tambah nilai ke enum response_status
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'on_scene'
          AND enumtypid = 'public.response_status'::regtype
    ) THEN
        ALTER TYPE public.response_status ADD VALUE 'on_scene';
    END IF;
END;
$$;

-- 3. Set default status
ALTER TABLE public.incident_responses
    ALTER COLUMN status SET DEFAULT 'on_scene'::public.response_status;

SELECT 'Migration 013 berhasil dijalankan.' AS status;
