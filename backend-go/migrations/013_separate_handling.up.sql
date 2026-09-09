-- ============================================================
-- SIAGAKITA — Migration 012: Separate Handling
-- Perubahan:
--   1. Tambah kolom handled_by_agency_id ke incidents
--   2. Tambah kolom agency_status ke incidents
--   3. Tambah nilai 'waiting_review' dan 'rejected' ke enum response_status
--   4. Tambah kolom proof_photo_url ke incident_responses
-- ============================================================

-- 1. Tambah kolom handled_by_agency_id ke incidents
ALTER TABLE public.incidents
    ADD COLUMN IF NOT EXISTS handled_by_agency_id uuid REFERENCES public.users(id);

-- 2. Tambah kolom agency_status ke incidents
ALTER TABLE public.incidents
    ADD COLUMN IF NOT EXISTS agency_status varchar(20) DEFAULT 'pending';

-- 3. Tambah nilai ke enum response_status
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'waiting_review'
          AND enumtypid = 'public.response_status'::regtype
    ) THEN
        ALTER TYPE public.response_status ADD VALUE 'waiting_review';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'rejected'
          AND enumtypid = 'public.response_status'::regtype
    ) THEN
        ALTER TYPE public.response_status ADD VALUE 'rejected';
    END IF;
END;
$$;

-- 4. Tambah kolom proof_photo_url ke incident_responses
ALTER TABLE public.incident_responses
    ADD COLUMN IF NOT EXISTS proof_photo_url varchar(255);

-- 5. Tambah tabel gamifikasi peringkat (badges)
CREATE TABLE IF NOT EXISTS public.m_badges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    badge_name varchar(50) NOT NULL,
    description text,
    icon_url varchar(255)
);

CREATE TABLE IF NOT EXISTS public.volunteer_badges_acquired (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    volunteer_id uuid NOT NULL REFERENCES public.users(id),
    badge_id uuid NOT NULL REFERENCES public.m_badges(id),
    acquired_at timestamp with time zone DEFAULT now()
);

SELECT 'Migration 012 berhasil dijalankan.' AS status;
