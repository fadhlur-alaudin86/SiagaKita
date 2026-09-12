-- ==========================================================================
-- Rollback Migration 022: Multi-Level Badges & Acquisition Constraints
-- ==========================================================================

ALTER TABLE public.volunteer_badges_acquired
    DROP CONSTRAINT IF EXISTS uq_volunteer_badges_acquired_user_badge;

ALTER TABLE public.m_badges
    DROP CONSTRAINT IF EXISTS uq_m_badges_code_level;

DELETE FROM public.m_badges
WHERE badge_code IN ('first_responder', 'medic_specialist', 'night_owl', 'rapid_hero', 'community_guardian');

ALTER TABLE public.m_badges
    DROP COLUMN IF EXISTS threshold,
    DROP COLUMN IF EXISTS level,
    DROP COLUMN IF EXISTS badge_code;
