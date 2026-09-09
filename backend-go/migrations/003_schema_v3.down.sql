-- Rollback for 003_schema_v3.up.sql

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

DROP TYPE IF EXISTS
    public.user_role,
    public.agency_type,
    public.blood_type_enum,
    public.cert_status,
    public.incident_category,
    public.incident_status,
    public.response_status
CASCADE;
