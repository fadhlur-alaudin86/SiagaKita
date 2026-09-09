-- Rollback for 019_add_missing_fk_indexes.up.sql

DROP INDEX IF EXISTS public.idx_admin_profiles_created_by;
DROP INDEX IF EXISTS public.idx_agencies_account_id;
DROP INDEX IF EXISTS public.idx_agency_personnels_user_id;
DROP INDEX IF EXISTS public.idx_incidents_handled_by_agency_id;
DROP INDEX IF EXISTS public.idx_sos_strikes_incident_id;
DROP INDEX IF EXISTS public.idx_sos_strikes_marked_by;
DROP INDEX IF EXISTS public.idx_sos_strikes_user_id;
DROP INDEX IF EXISTS public.idx_volunteer_badges_acquired_badge_id;
DROP INDEX IF EXISTS public.idx_volunteer_badges_acquired_user_id;
DROP INDEX IF EXISTS public.idx_volunteer_certifications_user_id;
DROP INDEX IF EXISTS public.idx_volunteer_certifications_verified_by;
DROP INDEX IF EXISTS public.idx_volunteer_reputation_rank_id;
DROP INDEX IF EXISTS public.idx_volunteer_reputation_user_id;
