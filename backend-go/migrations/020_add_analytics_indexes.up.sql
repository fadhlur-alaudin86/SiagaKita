-- Migration 020: Add performance indexes for incident analytics & gamification ranks
-- Complies with ECC Database Standards and postgres-patterns.md

-- Incident created_at filter index for temporal stats aggregation
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON public.incidents USING btree (created_at);

-- Incident status and created_at composite filter index for resolved / false_alarm queries
CREATE INDEX IF NOT EXISTS idx_incidents_status_created_at ON public.incidents USING btree (status, created_at);

-- Gamification ranks min_exp ordering and lookup index
CREATE INDEX IF NOT EXISTS idx_m_ranks_min_exp ON public.m_ranks USING btree (min_exp);
