-- Rollback for 020_add_analytics_indexes.up.sql

DROP INDEX IF EXISTS public.idx_incidents_created_at;
DROP INDEX IF EXISTS public.idx_incidents_status_created_at;
DROP INDEX IF EXISTS public.idx_m_ranks_min_exp;
