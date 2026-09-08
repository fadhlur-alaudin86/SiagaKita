-- Migration 018: Add supporting B-Tree indexes for unindexed foreign keys
-- Complies with ECC Database Standards and postgres-patterns.md

-- Admin & Agency relations
CREATE INDEX IF NOT EXISTS idx_admin_profiles_created_by ON public.admin_profiles USING btree (created_by);
CREATE INDEX IF NOT EXISTS idx_agencies_account_id ON public.agencies USING btree (account_id);
CREATE INDEX IF NOT EXISTS idx_agency_personnels_user_id ON public.agency_personnels USING btree (user_id);

-- Incident dispatch & handling
CREATE INDEX IF NOT EXISTS idx_incidents_handled_by_agency_id ON public.incidents USING btree (handled_by_agency_id);

-- SOS strikes & bans
CREATE INDEX IF NOT EXISTS idx_sos_strikes_incident_id ON public.sos_strikes USING btree (incident_id);
CREATE INDEX IF NOT EXISTS idx_sos_strikes_marked_by ON public.sos_strikes USING btree (marked_by);
CREATE INDEX IF NOT EXISTS idx_sos_strikes_user_id ON public.sos_strikes USING btree (user_id);

-- Volunteer gamification & badges
CREATE INDEX IF NOT EXISTS idx_volunteer_badges_acquired_badge_id ON public.volunteer_badges_acquired USING btree (badge_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_badges_acquired_user_id ON public.volunteer_badges_acquired USING btree (user_id);

-- Volunteer certifications
CREATE INDEX IF NOT EXISTS idx_volunteer_certifications_user_id ON public.volunteer_certifications USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_certifications_verified_by ON public.volunteer_certifications USING btree (verified_by);

-- Volunteer reputation & ranking
CREATE INDEX IF NOT EXISTS idx_volunteer_reputation_rank_id ON public.volunteer_reputation USING btree (rank_id);
CREATE INDEX IF NOT EXISTS idx_volunteer_reputation_user_id ON public.volunteer_reputation USING btree (user_id);
