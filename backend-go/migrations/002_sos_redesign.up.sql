-- ==========================================================================
-- SiagaKita — Migration 002: SOS Redesign & Laporan Warga
-- Jalankan SETELAH 001_init_schema.sql sudah dieksekusi
-- Idempotent: semua DDL menggunakan IF NOT EXISTS
-- ==========================================================================

-- 1. Enum baru: tingkat urgensi laporan warga
DO $$ BEGIN
    CREATE TYPE public.urgency_level AS ENUM ('low', 'medium', 'high');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. Tabel laporan warga (Jalur B — situasi non-darurat)
CREATE TABLE IF NOT EXISTS public.incident_reports (
    id            uuid        DEFAULT public.uuid_generate_v4() NOT NULL,
    reporter_id   uuid        NOT NULL,
    incident_type public.incident_category NOT NULL,
    urgency       public.urgency_level     DEFAULT 'low',
    latitude      numeric(10,8) NOT NULL,
    longitude     numeric(11,8) NOT NULL,
    description   text,
    photo_url     character varying(255),
    audio_url     character varying(255),
    status        character varying(20) DEFAULT 'pending',
    created_at    timestamp with time zone DEFAULT now(),
    updated_at    timestamp with time zone DEFAULT now(),
    CONSTRAINT incident_reports_pkey PRIMARY KEY (id),
    CONSTRAINT incident_reports_reporter_fk
        FOREIGN KEY (reporter_id) REFERENCES public.users(id)
);

CREATE INDEX IF NOT EXISTS idx_incident_reports_reporter
    ON public.incident_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_incident_reports_status
    ON public.incident_reports(status);

-- 3. Tabel audit strike false alarm
CREATE TABLE IF NOT EXISTS public.sos_strikes (
    id          uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id     uuid NOT NULL,
    incident_id uuid,
    reason      text,
    given_by    uuid,
    created_at  timestamp with time zone DEFAULT now(),
    CONSTRAINT sos_strikes_pkey PRIMARY KEY (id),
    CONSTRAINT sos_strikes_user_fk
        FOREIGN KEY (user_id) REFERENCES public.users(id),
    CONSTRAINT sos_strikes_incident_fk
        FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE SET NULL,
    CONSTRAINT sos_strikes_given_by_fk
        FOREIGN KEY (given_by) REFERENCES public.users(id)
);

CREATE INDEX IF NOT EXISTS idx_sos_strikes_user_id
    ON public.sos_strikes(user_id);

-- 4. Kolom baru di tabel users (anti-false alarm)
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS sos_strike_count  integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_sos_banned     boolean DEFAULT false,
    ADD COLUMN IF NOT EXISTS banned_until      timestamp with time zone;

-- 5. Trust label di incidents
ALTER TABLE public.incidents
    ADD COLUMN IF NOT EXISTS reporter_trust_label character varying(20) DEFAULT 'standard';

-- 6. Urgency level di incidents (SOS selalu critical)
ALTER TABLE public.incidents
    ADD COLUMN IF NOT EXISTS urgency_level character varying(10) DEFAULT 'critical';

-- ==========================================================================
-- Verifikasi:
-- SELECT column_name FROM information_schema.columns WHERE table_name='users' AND column_name LIKE 'sos%';
-- SELECT column_name FROM information_schema.columns WHERE table_name='incidents' AND column_name IN ('reporter_trust_label','urgency_level');
-- SELECT table_name FROM information_schema.tables WHERE table_name IN ('incident_reports','sos_strikes');
-- ==========================================================================
