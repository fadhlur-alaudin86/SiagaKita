# F-032 & F-033: Multi-Level Volunteer Badges Evaluation & Personal Mission History

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-032 / F-033 |
| Title | Multi-Level Volunteer Badges Evaluation & Personal Mission History |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-12 |
| GitHub Issues | [#8](https://github.com/fadhlur-alaudin86/SiagaKita/issues/8), [#32](https://github.com/fadhlur-alaudin86/SiagaKita/issues/32), [#33](https://github.com/fadhlur-alaudin86/SiagaKita/issues/33) |
| Parent Plan | `.planning/10-gamification-badges.md` |
| Status | In Progress |

---

## 1. Scope & Goals

- **Core Problem**:
  - While experience points (XP) and 5-tier ranks exist in the database and mobile UI, the badge achievement system remains static and lacks automated evaluation.
  - Volunteers who successfully resolve emergency rescues do not automatically receive milestone badges (`m_badges`), reducing engagement and recognition.
  - Badges currently lack a multi-tier/level progression model, preventing long-term goal setting for volunteers.
  - Volunteers have no interface in `mobile-flutter` to inspect their earned vs locked badge tiers or review their past emergency response mission logs.
  - Emergency agency administrators in `windows_console_flutter` have no master-detail interface to manage multi-level badges.
- **Boundaries**:
  - Backend: Schema migration for multi-level badges (`badge_code`, `level`, `threshold`), evaluation engine upon incident approval/resolution, idempotent insertion into `volunteer_badges_acquired`, real-time WebSocket celebration broadcast, and API endpoints for badge catalog and mission history.
  - Mobile: Interactive Badges Grid widget on volunteer profile (1 card per category with level indicator and progress bar), badge tier detail modal bottom sheet, offline-resilient vector icon fallbacks, and a dedicated Personal Mission History screen.
  - Desktop Console: Master-detail interface on `_BadgesTab` in `windows_console_flutter` (category overview with drill-down into level management).
- **Non-Goals**:
  - Dynamic user-created rule scripting (evaluators map to standard system criteria: mission count, medical count, night missions, response speed, and total rescues).

---

## 2. Architectural Decisions Log (Resolved via `/grill-me`)

1. **Hierarchical Master Badge Schema (`badge_code`, `level`, `threshold`)**:
   - **Decision**: Extend `m_badges` with `badge_code VARCHAR(50) NOT NULL`, `level INT NOT NULL DEFAULT 1`, and `threshold INT NOT NULL DEFAULT 1`, enforced with `UNIQUE(badge_code, level)`.
   - **Rationale**: Keeps database design flat, simple, and performant without creating redundant category tables, while allowing each level tier to carry its own custom name, description, and icon.
2. **Cumulative History in `volunteer_badges_acquired`**:
   - **Decision**: Record every newly unlocked level tier in `volunteer_badges_acquired` with `UNIQUE (user_id, badge_id)` and `ON CONFLICT DO NOTHING`.
   - **Rationale**: Preserves a full historical audit trail of when each level milestone was achieved. The client renders the highest acquired level for each category.
3. **Flexible Initial Milestone Configuration**:
   - **Decision**: Implement and seed 5 categories with customized level depth:
     - `first_responder` (3 levels: 1, 5, 15 missions)
     - `medic_specialist` (3 levels: 3, 10, 25 medical missions)
     - `night_owl` (3 levels: 3, 8, 20 night missions 22:00 - 05:00)
     - `rapid_hero` (3 levels: 1, 5, 15 rapid rescues < 15 min duration)
     - `community_guardian` (5 levels: 5, 15, 30, 60, 100 total rescues)
   - **Rationale**: Provides early onboarding momentum (Level 1 achieved quickly) and high ceiling for veteran volunteers.
4. **Desktop Console Master-Detail Management (`windows_console_flutter`)**:
   - **Decision**: Refactor `_BadgesTab` into a Master-Detail view:
     - Master View: Cards grouped by Badge Category (`badge_code`) showing level counts and "Kelola Level" action.
     - Detail View: Drill-down showing the list of level tiers for that category with "Tambah Level Baru", edit, and delete controls.
   - **Rationale**: Prevents a cluttered 20+ item flat list and provides intuitive hierarchical administration for dispatchers and admins.
5. **Mobile Category Cards with Level Progress (`mobile-flutter`)**:
   - **Decision**: Render 1 compact card per badge category on the volunteer profile. Displays the highest active level tier (stars/level badge), next level threshold, and progress bar. Tapping opens a bottom sheet showing all levels (unlocked date, current status, locked criteria).
   - **Rationale**: High information density without overwhelming the profile screen.
6. **Synchronous Evaluation with Multi-Channel Notification**:
   - **Decision**: Execute badge evaluation synchronously within `AgencyReviewVolunteer` and `Resolve`. Return newly unlocked badges in the HTTP response envelope, and broadcast WebSocket event `BADGE_UNLOCKED` to the volunteer's connected device.
   - **Rationale**: Provides immediate in-app celebration feedback without polling while maintaining transactional consistency.
7. **Offline-Resilient Vector Fallbacks with Grayscale Shader**:
   - **Decision**: Bundle local vector icon and gradient mappings as the primary fallback if remote `icon_url` is missing or network drops. Use `ColorFiltered` with a grayscale matrix for locked badges.
   - **Rationale**: Guarantees sharp, responsive, zero-layout-shift visuals in low-connectivity disaster zones.

---

## 3. Database Schema & Migration Specification

### Migration: `022_add_multi_level_badges_and_constraints.up.sql`

```sql
-- 1. Add badge_code, level, threshold to master badges table
ALTER TABLE public.m_badges
ADD COLUMN IF NOT EXISTS badge_code VARCHAR(50),
ADD COLUMN IF NOT EXISTS level INT NOT NULL DEFAULT 1,
ADD COLUMN IF NOT EXISTS threshold INT NOT NULL DEFAULT 1;

-- 2. Backfill existing rows if any
UPDATE public.m_badges SET badge_code = 'general' WHERE badge_code IS NULL;
ALTER TABLE public.m_badges ALTER COLUMN badge_code SET NOT NULL;

-- 3. Enforce uniqueness on (badge_code, level)
ALTER TABLE public.m_badges
ADD CONSTRAINT uq_m_badges_code_level UNIQUE (badge_code, level);

-- 4. Seed initial multi-level badges
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

-- 5. Enforce uniqueness on user badge acquisitions
ALTER TABLE public.volunteer_badges_acquired
ADD CONSTRAINT uq_volunteer_badges_acquired_user_badge UNIQUE (user_id, badge_id);
```

---

## 4. API Specification & Contracts

### 4.1 `GET /api/v1/volunteer/badges`
- **Auth**: Bearer JWT (Role: `volunteer` or `civilian`)
- **Response `200 OK`**:
  ```json
  {
    "code": 200,
    "message": "success",
    "data": [
      {
        "badge_code": "first_responder",
        "category_name": "First Responder",
        "current_level": 2,
        "max_level": 3,
        "current_progress": 8,
        "next_threshold": 15,
        "levels": [
          {
            "id": "uuid-1",
            "level": 1,
            "threshold": 1,
            "badge_name": "First Responder I",
            "description": "Selesaikan 1 misi penyelamatan darurat pertama",
            "icon_url": "badge_first_responder_1",
            "is_earned": true,
            "earned_at": "2026-09-12T10:00:00Z"
          },
          {
            "id": "uuid-2",
            "level": 2,
            "threshold": 5,
            "badge_name": "First Responder II",
            "description": "Selesaikan 5 misi penyelamatan darurat",
            "icon_url": "badge_first_responder_2",
            "is_earned": true,
            "earned_at": "2026-09-12T11:00:00Z"
          },
          {
            "id": "uuid-3",
            "level": 3,
            "threshold": 15,
            "badge_name": "First Responder III",
            "description": "Selesaikan 15 misi penyelamatan darurat",
            "icon_url": "badge_first_responder_3",
            "is_earned": false,
            "earned_at": null
          }
        ]
      }
    ]
  }
  ```

### 4.2 `GET /api/v1/incidents/missions/history`
- **Auth**: Bearer JWT (Role: `volunteer` or `agency`)
- **Query Params**: `page` (default: 1), `limit` (default: 20)
- **Response `200 OK`**:
  ```json
  {
    "code": 200,
    "message": "success",
    "data": [
      {
        "id": "uuid",
        "incident_id": "uuid",
        "incident_type": "medical",
        "status": "waiting_review",
        "accepted_at": "2026-09-12T08:00:00Z",
        "completed_at": "2026-09-12T08:14:00Z",
        "duration_minutes": 14,
        "proof_photo_url": "https://...",
        "address": "Jl. Merdeka No. 45, Jakarta",
        "latitude": -6.2088,
        "longitude": 106.8456
      }
    ]
  }
  ```

---

## 5. Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-12 | Identified Parent Issue #8 and Sub-Issues #32, #33 |
| -2 | Discovery & Grill-Me | Done | 2026-09-12 | Resolved multi-level badge architecture via /grill-me |
| -1 | Resolve Backlog | Done | 2026-09-12 | Updated specification `F-032-F-033-gamification-badges.md` |
| 0 | Branch & Assign | Done | 2026-09-12 | Topic branch `feature/F-032-F-033-gamification-badges` |
| 1 | DB Migration | Done | 2026-09-12 | Migration 022 added and `DATABASE_SCHEMA.md` synchronized |
| 2 | Backend Implementation | Done | 2026-09-12 | Evaluation engine, repository queries, routes, and unit tests |
| 3 | Desktop Console Update | Done | 2026-09-12 | Master-detail interface on `_BadgesTab` in Console |
| 4 | Mobile Implementation | Done | 2026-09-12 | BadgeGridWidget, modal sheet, mission history, and models |
| 5 | Verification | Done | 2026-09-12 | Pre-flight pipeline and test suites passed 100% |
| 6 | CI + Review | Pending | 2026-09-12 | Pull request targeting `dev` |
