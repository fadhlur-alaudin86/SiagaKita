-- ============================================================
-- SIAGAKITA - Drop & Recreate Schema (v3)
-- Jalankan manual:
--   sudo docker exec -i siagakita_postgres psql -U siagakita_admin -d siagakita < backend-go/migrations/003_schema_v3.sql
-- PERINGATAN: Semua data akan terhapus.
-- ============================================================

-- ── Drop semua tabel (urutan FK-safe) ────────────────────────
DROP TABLE IF EXISTS
    public.sos_strikes,
    public.incident_reports,
    public.volunteer_badges_acquired,
    public.volunteer_certifications,
    public.volunteer_reputation,
    public.incident_responses,
    public.incidents,
    public.emergency_contacts,
    public.agency_personnels,
    public.admin_profiles,
    public.user_profiles,
    public.user_medical_profiles,
    public.agencies,
    public.m_badges,
    public.m_ranks,
    public.users
CASCADE;

-- ── Drop tipe lama ────────────────────────────────────────────
DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.agency_type CASCADE;
DROP TYPE IF EXISTS public.blood_type_enum CASCADE;
DROP TYPE IF EXISTS public.cert_status CASCADE;
DROP TYPE IF EXISTS public.incident_category CASCADE;
DROP TYPE IF EXISTS public.incident_status CASCADE;
DROP TYPE IF EXISTS public.response_status CASCADE;

-- ── Drop functions lama ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.update_medical_timestamp() CASCADE;
DROP FUNCTION IF EXISTS public.update_volunteer_verification_status() CASCADE;
DROP FUNCTION IF EXISTS public.update_profile_timestamp() CASCADE;
DROP FUNCTION IF EXISTS public.sync_volunteer_verified() CASCADE;

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- ENUM TYPES
-- ============================================================
CREATE TYPE public.user_role AS ENUM (
    'superadmin',
    'admin',
    'agency',
    'agency_personnel',
    'volunteer',
    'civilian'
);

CREATE TYPE public.agency_type AS ENUM ('police', 'fire', 'medical', 'sar');

CREATE TYPE public.blood_type_enum AS ENUM ('A', 'B', 'AB', 'O', 'UNKNOWN');

CREATE TYPE public.cert_status AS ENUM ('pending', 'approved', 'rejected', 'expired');

CREATE TYPE public.incident_category AS ENUM (
    'medical', 'fire', 'crime', 'rescue', 'general', 'unknown'
);

CREATE TYPE public.incident_status AS ENUM (
    'grace_period', 'broadcasting', 'handled', 'resolved', 'false_alarm'
);

CREATE TYPE public.response_status AS ENUM (
    'en_route', 'on_scene', 'completed', 'canceled'
);

-- ============================================================
-- CORE: users (auth gateway - minimal)
-- ============================================================
CREATE TABLE public.users (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    email         varchar(100) NOT NULL UNIQUE,
    password_hash varchar(255) NOT NULL,
    role          public.user_role NOT NULL DEFAULT 'civilian',
    created_at    timestamptz DEFAULT now() NOT NULL,
    deleted_at    timestamptz
);
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_role  ON public.users(role);
CREATE INDEX idx_users_del   ON public.users(deleted_at);

-- ============================================================
-- PROFIL: admin_profiles (hanya untuk role admin)
-- agency tidak perlu karena nama ada di tabel agencies
-- ============================================================
CREATE TABLE public.admin_profiles (
    user_id    uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    full_name  varchar(100),
    created_by uuid REFERENCES public.users(id),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- ============================================================
-- PROFIL: user_profiles (citizen & volunteer)
-- ============================================================
CREATE TABLE public.user_profiles (
    user_id               uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    full_name             varchar(100),
    nik                   varchar(16) UNIQUE,
    date_of_birth         date,
    phone_number          varchar(20) UNIQUE,
    is_email_verified     boolean DEFAULT false,
    is_phone_verified     boolean DEFAULT false,
    is_verified_volunteer boolean DEFAULT false,
    sos_strike_count      int DEFAULT 0,
    is_sos_banned         boolean DEFAULT false,
    banned_until          timestamptz,
    blood_type            public.blood_type_enum DEFAULT 'UNKNOWN',
    allergies             text,
    medical_conditions    text,
    height_cm             int CHECK (height_cm > 0),
    weight_kg             int CHECK (weight_kg > 0),
    alamat                text,
    updated_at            timestamptz DEFAULT now()
);
CREATE INDEX idx_up_phone ON public.user_profiles(phone_number);
CREATE INDEX idx_up_nik   ON public.user_profiles(nik);

-- ============================================================
-- AGENCIES
-- ============================================================
CREATE TABLE public.agencies (
    id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name           varchar(100) NOT NULL,
    type           public.agency_type NOT NULL,
    city_code      varchar(50) NOT NULL,
    hotline_number varchar(20),
    -- FK ke akun agency di users
    account_id     uuid UNIQUE REFERENCES public.users(id),
    created_at     timestamptz DEFAULT now()
);

-- ============================================================
-- AGENCY PERSONNELS
-- ============================================================
CREATE TABLE public.agency_personnels (
    user_id      uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    agency_id    uuid NOT NULL REFERENCES public.agencies(id) ON DELETE RESTRICT,
    full_name    varchar(100) NOT NULL,
    badge_number varchar(50) NOT NULL UNIQUE,
    is_active    boolean DEFAULT true,
    created_at   timestamptz DEFAULT now()
);
CREATE INDEX idx_ap_agency ON public.agency_personnels(agency_id);

-- ============================================================
-- EMERGENCY CONTACTS
-- ============================================================
CREATE TABLE public.emergency_contacts (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id       uuid REFERENCES public.users(id) ON DELETE CASCADE,
    contact_name  varchar(100) NOT NULL,
    contact_phone varchar(20) NOT NULL,
    relation      varchar(50),
    created_at    timestamptz DEFAULT now(),
    deleted_at    timestamptz
);
CREATE INDEX idx_ec_user ON public.emergency_contacts(user_id);

-- ============================================================
-- INCIDENTS
-- ============================================================
CREATE TABLE public.incidents (
    id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id          uuid REFERENCES public.users(id),
    incident_type        public.incident_category NOT NULL DEFAULT 'unknown',
    latitude             numeric(10,8) NOT NULL,
    longitude            numeric(11,8) NOT NULL,
    status               public.incident_status DEFAULT 'grace_period',
    urgency_level        varchar(10) DEFAULT 'unknown',
    reporter_trust_label varchar(20) DEFAULT 'standard',
    address_detail       text,
    trigger_method       varchar(20) DEFAULT 'timeout',
    created_at           timestamptz DEFAULT now() NOT NULL,
    updated_at           timestamptz DEFAULT now(),
    completed_at         timestamptz
);
CREATE INDEX idx_incidents_reporter ON public.incidents(reporter_id);
CREATE INDEX idx_incidents_status   ON public.incidents(status);

-- ============================================================
-- INCIDENT REPORTS (Jalur B - non-darurat)
-- ============================================================
CREATE TABLE public.incident_reports (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id   uuid REFERENCES public.users(id),
    incident_type public.incident_category NOT NULL DEFAULT 'general',
    urgency       varchar(10) DEFAULT 'low',
    latitude      numeric(10,8) NOT NULL,
    longitude     numeric(11,8) NOT NULL,
    description   text,
    photo_url     varchar(255),
    audio_url     varchar(255),
    status        varchar(20) DEFAULT 'pending',
    created_at    timestamptz DEFAULT now()
);

-- ============================================================
-- INCIDENT RESPONSES (dispatch)
-- ============================================================
CREATE TABLE public.incident_responses (
    id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    incident_id  uuid REFERENCES public.incidents(id) ON DELETE CASCADE,
    responder_id uuid REFERENCES public.users(id),
    status       public.response_status DEFAULT 'en_route',
    accepted_at  timestamptz DEFAULT now(),
    arrived_at   timestamptz,
    UNIQUE (incident_id, responder_id)
);
CREATE INDEX idx_ir_incident  ON public.incident_responses(incident_id);
CREATE INDEX idx_ir_responder ON public.incident_responses(responder_id);

-- ============================================================
-- SOS STRIKES
-- ============================================================
CREATE TABLE public.sos_strikes (
    id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     uuid REFERENCES public.users(id) ON DELETE CASCADE,
    incident_id uuid REFERENCES public.incidents(id) ON DELETE SET NULL,
    reason      text,
    marked_by   uuid REFERENCES public.users(id),
    created_at  timestamptz DEFAULT now()
);

-- ============================================================
-- MASTER DATA: Ranks & Badges
-- ============================================================
CREATE TABLE public.m_ranks (
    id        serial PRIMARY KEY,
    rank_name varchar(50) NOT NULL,
    min_exp   int NOT NULL,
    icon_url  varchar(255)
);

CREATE TABLE public.m_badges (
    id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    badge_name  varchar(50) NOT NULL,
    description text,
    icon_url    varchar(255)
);

-- ============================================================
-- VOLUNTEER: Reputation & Certifications & Badges
-- ============================================================
CREATE TABLE public.volunteer_reputation (
    user_id       uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    exp_points    int DEFAULT 0,
    rank_id       int REFERENCES public.m_ranks(id),
    total_rescues int DEFAULT 0,
    updated_at    timestamptz DEFAULT now()
);

CREATE TABLE public.volunteer_certifications (
    id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id          uuid REFERENCES public.users(id) ON DELETE CASCADE,
    certificate_type varchar(50) NOT NULL,
    document_url     varchar(255) NOT NULL,
    status           public.cert_status DEFAULT 'pending',
    verified_by      uuid REFERENCES public.users(id),
    expires_at       date,
    created_at       timestamptz DEFAULT now()
);

CREATE TABLE public.volunteer_badges_acquired (
    id        uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id   uuid REFERENCES public.users(id) ON DELETE CASCADE,
    badge_id  uuid REFERENCES public.m_badges(id),
    earned_at timestamptz DEFAULT now()
);

-- ============================================================
-- TRIGGERS
-- ============================================================

-- update_at auto pada user_profiles
CREATE OR REPLACE FUNCTION public.fn_update_profile_ts()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

CREATE TRIGGER trg_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_profile_ts();

CREATE TRIGGER trg_admin_profiles_updated_at
    BEFORE UPDATE ON public.admin_profiles
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_profile_ts();

-- Sync is_verified_volunteer ke user_profiles saat cert status berubah
CREATE OR REPLACE FUNCTION public.fn_sync_volunteer_verified()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'approved' THEN
        UPDATE public.user_profiles
           SET is_verified_volunteer = TRUE
         WHERE user_id = NEW.user_id;
    ELSIF OLD.status = 'approved' AND NEW.status != 'approved' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.volunteer_certifications
             WHERE user_id = NEW.user_id
               AND status = 'approved'
               AND id != NEW.id
        ) THEN
            UPDATE public.user_profiles
               SET is_verified_volunteer = FALSE
             WHERE user_id = NEW.user_id;
        END IF;
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_sync_volunteer_verified
    AFTER UPDATE ON public.volunteer_certifications
    FOR EACH ROW EXECUTE FUNCTION public.fn_sync_volunteer_verified();

-- ============================================================
-- DONE
-- ============================================================
SELECT 'Schema v3 berhasil dibuat.' AS status;
