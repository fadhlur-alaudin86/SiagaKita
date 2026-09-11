-- ==========================================================================
-- SiagaKita — Migration 021: Standardize VARCHAR Constraints & Relations
-- Replaces PostgreSQL custom ENUMs with Domain-Constrained VARCHAR (CHECK constraints)
-- Normalizes emergency_contacts.relation to standard keys:
--   'parent', 'spouse', 'child', 'sibling', 'friend', 'other'
-- Purges orphaned/superseded custom ENUM types.
-- ==========================================================================

-- 1. Normalize existing emergency_contacts.relation data
UPDATE public.emergency_contacts
SET relation = CASE
    WHEN LOWER(TRIM(relation)) IN ('ayah', 'ibu', 'orang tua', 'bapak', 'mama', 'papa', 'father', 'mother', 'parent', 'orangtua', 'wali') THEN 'parent'
    WHEN LOWER(TRIM(relation)) IN ('suami', 'istri', 'pasangan', 'husband', 'wife', 'spouse') THEN 'spouse'
    WHEN LOWER(TRIM(relation)) IN ('anak', 'anak kandung', 'son', 'daughter', 'child') THEN 'child'
    WHEN LOWER(TRIM(relation)) IN ('kakak', 'adik', 'saudara', 'saudara kandung', 'brother', 'sister', 'sibling', 'abang') THEN 'sibling'
    WHEN LOWER(TRIM(relation)) IN ('teman', 'sahabat', 'kawan', 'tetangga', 'kerabat', 'friend') THEN 'friend'
    ELSE 'other'
END
WHERE relation IS NOT NULL AND TRIM(relation) != '';

-- Constraint for emergency_contacts.relation
ALTER TABLE public.emergency_contacts
    DROP CONSTRAINT IF EXISTS chk_emergency_contacts_relation;
ALTER TABLE public.emergency_contacts
    ADD CONSTRAINT chk_emergency_contacts_relation
    CHECK (relation IS NULL OR relation IN ('parent', 'spouse', 'child', 'sibling', 'friend', 'other'));

-- 2. Standardize incidents table
ALTER TABLE public.incidents ALTER COLUMN incident_type DROP DEFAULT;
ALTER TABLE public.incidents ALTER COLUMN incident_type TYPE varchar(50) USING incident_type::text;
ALTER TABLE public.incidents ALTER COLUMN incident_type SET DEFAULT 'unknown';
ALTER TABLE public.incidents DROP CONSTRAINT IF EXISTS chk_incidents_incident_type;
ALTER TABLE public.incidents ADD CONSTRAINT chk_incidents_incident_type
    CHECK (incident_type IN ('medical', 'fire', 'crime', 'rescue', 'disaster', 'general', 'unknown'));

ALTER TABLE public.incidents ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.incidents ALTER COLUMN status TYPE varchar(30) USING status::text;
ALTER TABLE public.incidents ALTER COLUMN status SET DEFAULT 'grace_period';
ALTER TABLE public.incidents DROP CONSTRAINT IF EXISTS chk_incidents_status;
ALTER TABLE public.incidents ADD CONSTRAINT chk_incidents_status
    CHECK (status IN ('grace_period', 'broadcasting', 'handling', 'handled', 'resolved', 'false_alarm', 'canceled'));

ALTER TABLE public.incidents DROP CONSTRAINT IF EXISTS chk_incidents_agency_status;
ALTER TABLE public.incidents ADD CONSTRAINT chk_incidents_agency_status
    CHECK (agency_status IS NULL OR agency_status IN ('pending', 'accepted', 'declined', 'handling', 'completed', 'canceled'));

ALTER TABLE public.incidents DROP CONSTRAINT IF EXISTS chk_incidents_reporter_trust_label;
ALTER TABLE public.incidents ADD CONSTRAINT chk_incidents_reporter_trust_label
    CHECK (reporter_trust_label IS NULL OR reporter_trust_label IN ('standard', 'trusted', 'untrusted', 'verified', 'unverified'));

-- 3. Standardize incident_reports table (Jalur B)
ALTER TABLE public.incident_reports DROP CONSTRAINT IF EXISTS chk_incident_reports_status;
ALTER TABLE public.incident_reports ADD CONSTRAINT chk_incident_reports_status
    CHECK (status IN ('received', 'sent', 'processing', 'investigating', 'handled', 'resolved', 'rejected', 'canceled'));

ALTER TABLE public.incident_reports DROP CONSTRAINT IF EXISTS chk_incident_reports_incident_type;
ALTER TABLE public.incident_reports ADD CONSTRAINT chk_incident_reports_incident_type
    CHECK (incident_type IN ('medical', 'fire', 'crime', 'rescue', 'disaster', 'general', 'unknown'));

-- 4. Standardize incident_responses table
ALTER TABLE public.incident_responses ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.incident_responses ALTER COLUMN status TYPE varchar(30) USING status::text;
ALTER TABLE public.incident_responses ALTER COLUMN status SET DEFAULT 'en_route';
ALTER TABLE public.incident_responses DROP CONSTRAINT IF EXISTS chk_incident_responses_status;
ALTER TABLE public.incident_responses ADD CONSTRAINT chk_incident_responses_status
    CHECK (status IN ('en_route', 'on_scene', 'waiting_review', 'completed', 'rejected', 'canceled'));

-- 5. Standardize users table
ALTER TABLE public.users ALTER COLUMN role DROP DEFAULT;
ALTER TABLE public.users ALTER COLUMN role TYPE varchar(30) USING role::text;
ALTER TABLE public.users ALTER COLUMN role SET DEFAULT 'civilian';
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS chk_users_role;
ALTER TABLE public.users ADD CONSTRAINT chk_users_role
    CHECK (role IN ('superadmin', 'admin', 'agency', 'agency_personnel', 'volunteer', 'civilian'));

-- 6. Standardize agencies table
ALTER TABLE public.agencies ALTER COLUMN type TYPE varchar(20) USING type::text;
ALTER TABLE public.agencies DROP CONSTRAINT IF EXISTS chk_agencies_type;
ALTER TABLE public.agencies ADD CONSTRAINT chk_agencies_type
    CHECK (type IN ('police', 'fire', 'medical', 'sar'));

-- 7. Standardize volunteer_certifications table
ALTER TABLE public.volunteer_certifications ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.volunteer_certifications ALTER COLUMN status TYPE varchar(20) USING status::text;
ALTER TABLE public.volunteer_certifications ALTER COLUMN status SET DEFAULT 'pending';
ALTER TABLE public.volunteer_certifications DROP CONSTRAINT IF EXISTS chk_volunteer_certifications_status;
ALTER TABLE public.volunteer_certifications ADD CONSTRAINT chk_volunteer_certifications_status
    CHECK (status IN ('pending', 'approved', 'rejected', 'expired'));

-- 8. Standardize user_profiles table
ALTER TABLE public.user_profiles ALTER COLUMN blood_type DROP DEFAULT;
ALTER TABLE public.user_profiles ALTER COLUMN blood_type TYPE varchar(10) USING blood_type::text;
ALTER TABLE public.user_profiles ALTER COLUMN blood_type SET DEFAULT 'UNKNOWN';
ALTER TABLE public.user_profiles DROP CONSTRAINT IF EXISTS chk_user_profiles_blood_type;
ALTER TABLE public.user_profiles ADD CONSTRAINT chk_user_profiles_blood_type
    CHECK (blood_type IN ('A', 'B', 'AB', 'O', 'UNKNOWN', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'));

-- 9. Drop orphaned and superseded custom PostgreSQL ENUM types
DROP TYPE IF EXISTS public.incident_status CASCADE;
DROP TYPE IF EXISTS public.incident_category CASCADE;
DROP TYPE IF EXISTS public.response_status CASCADE;
DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.agency_type CASCADE;
DROP TYPE IF EXISTS public.cert_status CASCADE;
DROP TYPE IF EXISTS public.blood_type_enum CASCADE;
DROP TYPE IF EXISTS public.urgency_level CASCADE;
