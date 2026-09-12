-- ==========================================================================
-- SiagaKita — Migration 022: Multi-Level Badges & Acquisition Constraints
-- Extends m_badges with badge_code, level, and threshold.
-- Enforces UNIQUE(badge_code, level) on m_badges.
-- Seeds 17 multi-level master badges across 5 core categories.
-- Enforces UNIQUE(user_id, badge_id) on volunteer_badges_acquired.
-- ==========================================================================

-- 1. Add badge_code, level, threshold to master badges table
ALTER TABLE public.m_badges
    ADD COLUMN IF NOT EXISTS badge_code VARCHAR(50),
    ADD COLUMN IF NOT EXISTS level INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS threshold INT NOT NULL DEFAULT 1;

-- Backfill any existing badges without badge_code
UPDATE public.m_badges
SET badge_code = LOWER(REPLACE(badge_name, ' ', '_'))
WHERE badge_code IS NULL;

ALTER TABLE public.m_badges
    ALTER COLUMN badge_code SET NOT NULL;

-- 2. Add unique constraint on (badge_code, level)
ALTER TABLE public.m_badges
    DROP CONSTRAINT IF EXISTS uq_m_badges_code_level;

ALTER TABLE public.m_badges
    ADD CONSTRAINT uq_m_badges_code_level UNIQUE (badge_code, level);

-- 3. Seed default multi-level badges
INSERT INTO public.m_badges (badge_code, level, threshold, badge_name, description, icon_url)
VALUES
    -- First Responder (1, 5, 15)
    ('first_responder', 1, 1, 'First Responder I', 'Selesaikan 1 misi penyelamatan darurat pertama', 'badge_first_responder_1'),
    ('first_responder', 2, 5, 'First Responder II', 'Selesaikan 5 misi penyelamatan darurat', 'badge_first_responder_2'),
    ('first_responder', 3, 15, 'First Responder III', 'Selesaikan 15 misi penyelamatan darurat', 'badge_first_responder_3'),

    -- Medic Specialist (3, 10, 25)
    ('medic_specialist', 1, 3, 'Medic Specialist I', 'Selesaikan 3 misi darurat medis', 'badge_medic_specialist_1'),
    ('medic_specialist', 2, 10, 'Medic Specialist II', 'Selesaikan 10 misi darurat medis', 'badge_medic_specialist_2'),
    ('medic_specialist', 3, 25, 'Medic Specialist III', 'Selesaikan 25 misi darurat medis', 'badge_medic_specialist_3'),

    -- Night Owl (3, 8, 20)
    ('night_owl', 1, 3, 'Night Owl I', 'Selesaikan 3 misi darurat malam hari (22:00 - 05:00)', 'badge_night_owl_1'),
    ('night_owl', 2, 8, 'Night Owl II', 'Selesaikan 8 misi darurat malam hari (22:00 - 05:00)', 'badge_night_owl_2'),
    ('night_owl', 3, 20, 'Night Owl III', 'Selesaikan 20 misi darurat malam hari (22:00 - 05:00)', 'badge_night_owl_3'),

    -- Rapid Hero (1, 5, 15)
    ('rapid_hero', 1, 1, 'Rapid Hero I', 'Selesaikan 1 misi dengan durasi respon di bawah 15 menit', 'badge_rapid_hero_1'),
    ('rapid_hero', 2, 5, 'Rapid Hero II', 'Selesaikan 5 misi dengan durasi respon di bawah 15 menit', 'badge_rapid_hero_2'),
    ('rapid_hero', 3, 15, 'Rapid Hero III', 'Selesaikan 15 misi dengan durasi respon di bawah 15 menit', 'badge_rapid_hero_3'),

    -- Community Guardian (5, 15, 30, 60, 100)
    ('community_guardian', 1, 5, 'Community Guardian I', 'Selesaikan 5 total misi penyelamatan terverifikasi', 'badge_community_guardian_1'),
    ('community_guardian', 2, 15, 'Community Guardian II', 'Selesaikan 15 total misi penyelamatan terverifikasi', 'badge_community_guardian_2'),
    ('community_guardian', 3, 30, 'Community Guardian III', 'Selesaikan 30 total misi penyelamatan terverifikasi', 'badge_community_guardian_3'),
    ('community_guardian', 4, 60, 'Community Guardian IV', 'Selesaikan 60 total misi penyelamatan terverifikasi', 'badge_community_guardian_4'),
    ('community_guardian', 5, 100, 'Community Guardian V', 'Selesaikan 100 total misi penyelamatan terverifikasi', 'badge_community_guardian_5')
ON CONFLICT (badge_code, level) DO UPDATE
SET threshold = EXCLUDED.threshold,
    badge_name = EXCLUDED.badge_name,
    description = EXCLUDED.description,
    icon_url = EXCLUDED.icon_url;

-- 4. Enforce uniqueness on user badge acquisitions
ALTER TABLE public.volunteer_badges_acquired
    DROP CONSTRAINT IF EXISTS uq_volunteer_badges_acquired_user_badge;

ALTER TABLE public.volunteer_badges_acquired
    ADD CONSTRAINT uq_volunteer_badges_acquired_user_badge UNIQUE (user_id, badge_id);
