-- ==========================================================================
-- Rollback for 001_init_schema.up.sql
-- Drop tables, functions, and enum types in FK-safe reverse order
-- ==========================================================================

DROP TABLE IF EXISTS
    public.volunteer_reputation,
    public.volunteer_certifications,
    public.volunteer_badges_acquired,
    public.user_medical_profiles,
    public.emergency_contacts,
    public.agency_personnels,
    public.incident_responses,
    public.incidents,
    public.agencies,
    public.m_ranks,
    public.m_badges,
    public.users
CASCADE;

DROP FUNCTION IF EXISTS public.update_volunteer_verification_status() CASCADE;
DROP FUNCTION IF EXISTS public.update_medical_timestamp() CASCADE;

DROP TYPE IF EXISTS
    public.user_role,
    public.response_status,
    public.incident_status,
    public.incident_category,
    public.cert_status,
    public.blood_type_enum,
    public.agency_type
CASCADE;
