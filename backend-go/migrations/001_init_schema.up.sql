-- ==========================================================================
-- SiagaKita — Migration 001: Initial Schema
-- Tables, Enums, Extensions, Functions, Triggers, and Indexes
-- ==========================================================================

-- --------------------------------------------------------------------------
-- 1. EXTENSIONS
-- --------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- --------------------------------------------------------------------------
-- 2. ENUM TYPES
-- --------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE public.agency_type AS ENUM ('police', 'fire', 'medical', 'sar');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.blood_type_enum AS ENUM ('A', 'B', 'AB', 'O', 'UNKNOWN');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.cert_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.incident_category AS ENUM ('medical', 'fire', 'crime', 'rescue', 'general');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.incident_status AS ENUM ('grace_period', 'broadcasting', 'handled', 'resolved', 'false_alarm');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.response_status AS ENUM ('en_route', 'on_scene', 'completed', 'canceled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.user_role AS ENUM ('civilian', 'volunteer', 'agency_responder', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- --------------------------------------------------------------------------
-- 3. TRIGGER FUNCTIONS
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_medical_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_volunteer_verification_status()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        IF NEW.status = 'approved' THEN
            UPDATE public.users SET is_verified_volunteer = TRUE WHERE id = NEW.user_id;
        ELSIF OLD.status = 'approved' AND NEW.status != 'approved' THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.volunteer_certifications
                WHERE user_id = NEW.user_id AND status = 'approved' AND id != NEW.id
            ) THEN
                UPDATE public.users SET is_verified_volunteer = FALSE WHERE id = NEW.user_id;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------------------------
-- 4. TABLES & CONSTRAINTS
-- --------------------------------------------------------------------------

-- 4.1 Users
CREATE TABLE IF NOT EXISTS public.users (
    id                    uuid PRIMARY KEY DEFAULT public.uuid_generate_v4(),
    full_name             varchar(100) NOT NULL,
    nik                   varchar(16) UNIQUE,
    date_of_birth         date,
    phone_number          varchar(20) UNIQUE,
    email                 varchar(100) NOT NULL UNIQUE,
    password_hash         varchar(255) NOT NULL,
    role                  public.user_role NOT NULL DEFAULT 'civilian',
    is_verified_volunteer boolean DEFAULT false,
    created_at            timestamptz DEFAULT now() NOT NULL,
    updated_at            timestamptz DEFAULT now(),
    deleted_at            timestamptz,
    is_email_verified     boolean DEFAULT false,
    is_phone_verified     boolean DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON public.users(deleted_at);

-- 4.2 Badges & Ranks
CREATE TABLE IF NOT EXISTS public.m_badges (
    id          uuid PRIMARY KEY DEFAULT public.uuid_generate_v4(),
    badge_name  varchar(50) NOT NULL UNIQUE,
    description text,
    icon_url    varchar(255)
);

CREATE TABLE IF NOT EXISTS public.m_ranks (
    id        serial PRIMARY KEY,
    rank_name varchar(50) NOT NULL UNIQUE,
    min_exp   integer NOT NULL,
    icon_url  varchar(255)
);

-- 4.3 Agencies & Personnel
CREATE TABLE IF NOT EXISTS public.agencies (
    id             uuid PRIMARY KEY DEFAULT public.uuid_generate_v4(),
    name           varchar(100) NOT NULL,
    type           public.agency_type NOT NULL,
    city_code      varchar(50) NOT NULL,
    hotline_number varchar(20)
);

CREATE TABLE IF NOT EXISTS public.agency_personnels (
    user_id      uuid PRIMARY KEY REFERENCES public.users(id),
    agency_id    uuid REFERENCES public.agencies(id) ON DELETE RESTRICT,
    badge_number varchar(50) NOT NULL UNIQUE
);

-- 4.4 Emergency Contacts
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id            uuid PRIMARY KEY DEFAULT public.uuid_generate_v4(),
    user_id       uuid REFERENCES public.users(id),
    contact_name  varchar(100) NOT NULL,
    contact_phone varchar(20) NOT NULL,
    relation      varchar(50),
    created_at    timestamptz DEFAULT now(),
    deleted_at    timestamptz
);

CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON public.emergency_contacts(user_id);

-- 4.5 Incidents & Responses
CREATE TABLE IF NOT EXISTS public.incidents (
    id             uuid PRIMARY KEY DEFAULT public.uuid_generate_v4(),
    reporter_id    uuid REFERENCES public.users(id),
    incident_type  public.incident_category NOT NULL,
    latitude       numeric(10,8) NOT NULL,
    longitude      numeric(11,8) NOT NULL,
    status         public.incident_status DEFAULT 'grace_period',
    address_detail text,
    created_at     timestamptz DEFAULT now() NOT NULL,
    updated_at     timestamptz DEFAULT now(),
    resolved_at    timestamptz,
    trigger_method varchar(20) NOT NULL DEFAULT 'timeout'
);

CREATE INDEX IF NOT EXISTS idx_incidents_reporter_id ON public.incidents(reporter_id);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON public.incidents(status);

CREATE TABLE IF NOT EXISTS public.incident_responses (
    id           uuid PRIMARY KEY DEFAULT public.uuid_generate_v4(),
    incident_id  uuid REFERENCES public.incidents(id) ON DELETE CASCADE,
    responder_id uuid REFERENCES public.users(id),
    status       public.response_status DEFAULT 'en_route',
    accepted_at  timestamptz DEFAULT now(),
    arrived_at   timestamptz,
    CONSTRAINT unique_responder_per_incident UNIQUE (incident_id, responder_id)
);

CREATE INDEX IF NOT EXISTS idx_incident_responses_incident_id ON public.incident_responses(incident_id);
CREATE INDEX IF NOT EXISTS idx_incident_responses_responder_id ON public.incident_responses(responder_id);

-- 4.6 User Medical Profiles
CREATE TABLE IF NOT EXISTS public.user_medical_profiles (
    user_id            uuid PRIMARY KEY REFERENCES public.users(id),
    blood_type         public.blood_type_enum DEFAULT 'UNKNOWN',
    allergies          text,
    medical_conditions text,
    height_cm          integer CHECK (height_cm > 0),
    weight_kg          integer CHECK (weight_kg > 0),
    domicile           text,
    updated_at         timestamptz DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_medical_updated_at ON public.user_medical_profiles;
CREATE TRIGGER trg_medical_updated_at
    BEFORE UPDATE ON public.user_medical_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_medical_timestamp();

-- 4.7 Volunteer Gamification & Certifications
CREATE TABLE IF NOT EXISTS public.volunteer_badges_acquired (
    id        uuid PRIMARY KEY DEFAULT public.uuid_generate_v4(),
    user_id   uuid REFERENCES public.users(id),
    badge_id  uuid REFERENCES public.m_badges(id),
    earned_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.volunteer_certifications (
    id               uuid PRIMARY KEY DEFAULT public.uuid_generate_v4(),
    user_id          uuid REFERENCES public.users(id),
    certificate_type varchar(50) NOT NULL,
    document_url     varchar(255) NOT NULL,
    status           public.cert_status DEFAULT 'pending',
    verified_by      uuid REFERENCES public.users(id),
    expires_at       date,
    created_at       timestamptz DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_update_volunteer_status ON public.volunteer_certifications;
CREATE TRIGGER trg_update_volunteer_status
    AFTER UPDATE ON public.volunteer_certifications
    FOR EACH ROW
    EXECUTE FUNCTION public.update_volunteer_verification_status();

CREATE TABLE IF NOT EXISTS public.volunteer_reputation (
    user_id       uuid PRIMARY KEY REFERENCES public.users(id),
    exp_points    integer DEFAULT 0,
    rank_id       integer REFERENCES public.m_ranks(id),
    total_rescues integer DEFAULT 0,
    updated_at    timestamp DEFAULT now()
);
