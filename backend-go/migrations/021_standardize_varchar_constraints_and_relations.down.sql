-- ==========================================================================
-- SiagaKita — Migration 021 Down: Revert VARCHAR Constraints & Restore ENUMs
-- ==========================================================================

-- 1. Recreate original ENUM types
DO $$ BEGIN
    CREATE TYPE public.incident_category AS ENUM ('medical', 'fire', 'crime', 'rescue', 'disaster', 'general', 'unknown');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.incident_status AS ENUM ('grace_period', 'broadcasting', 'handling', 'handled', 'resolved', 'false_alarm', 'canceled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.response_status AS ENUM ('en_route', 'on_scene', 'waiting_review', 'completed', 'rejected', 'canceled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.user_role AS ENUM ('superadmin', 'admin', 'agency', 'agency_personnel', 'volunteer', 'civilian');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.agency_type AS ENUM ('police', 'fire', 'medical', 'sar');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.cert_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.blood_type_enum AS ENUM ('A', 'B', 'AB', 'O', 'UNKNOWN', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.urgency_level AS ENUM ('low', 'medium', 'high');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Drop constraints and cast columns back to ENUMs
ALTER TABLE public.emergency_contacts DROP CONSTRAINT IF EXISTS chk_emergency_contacts_relation;

ALTER TABLE public.incidents DROP CONSTRAINT IF EXISTS chk_incidents_agency_status;
ALTER TABLE public.incidents DROP CONSTRAINT IF EXISTS chk_incidents_reporter_trust_label;
ALTER TABLE public.incidents DROP CONSTRAINT IF EXISTS chk_incidents_incident_type;
ALTER TABLE public.incidents ALTER COLUMN incident_type DROP DEFAULT;
ALTER TABLE public.incidents ALTER COLUMN incident_type TYPE public.incident_category USING incident_type::public.incident_category;
ALTER TABLE public.incidents ALTER COLUMN incident_type SET DEFAULT 'unknown';

ALTER TABLE public.incidents DROP CONSTRAINT IF EXISTS chk_incidents_status;
ALTER TABLE public.incidents ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.incidents ALTER COLUMN status TYPE public.incident_status USING status::public.incident_status;
ALTER TABLE public.incidents ALTER COLUMN status SET DEFAULT 'grace_period';

ALTER TABLE public.incident_reports DROP CONSTRAINT IF EXISTS chk_incident_reports_status;
ALTER TABLE public.incident_reports DROP CONSTRAINT IF EXISTS chk_incident_reports_incident_type;

ALTER TABLE public.incident_responses DROP CONSTRAINT IF EXISTS chk_incident_responses_status;
ALTER TABLE public.incident_responses ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.incident_responses ALTER COLUMN status TYPE public.response_status USING status::public.response_status;
ALTER TABLE public.incident_responses ALTER COLUMN status SET DEFAULT 'en_route';

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS chk_users_role;
ALTER TABLE public.users ALTER COLUMN role DROP DEFAULT;
ALTER TABLE public.users ALTER COLUMN role TYPE public.user_role USING role::public.user_role;
ALTER TABLE public.users ALTER COLUMN role SET DEFAULT 'civilian';

ALTER TABLE public.agencies DROP CONSTRAINT IF EXISTS chk_agencies_type;
ALTER TABLE public.agencies ALTER COLUMN type TYPE public.agency_type USING type::public.agency_type;

ALTER TABLE public.volunteer_certifications DROP CONSTRAINT IF EXISTS chk_volunteer_certifications_status;
ALTER TABLE public.volunteer_certifications ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.volunteer_certifications ALTER COLUMN status TYPE public.cert_status USING status::public.cert_status;
ALTER TABLE public.volunteer_certifications ALTER COLUMN status SET DEFAULT 'pending';

ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS chk_user_profiles_blood_type;
ALTER TABLE public.user_profiles ALTER COLUMN blood_type DROP DEFAULT;
ALTER TABLE public.user_profiles ALTER COLUMN blood_type TYPE public.blood_type_enum USING blood_type::public.blood_type_enum;
ALTER TABLE public.user_profiles ALTER COLUMN blood_type SET DEFAULT 'UNKNOWN';
