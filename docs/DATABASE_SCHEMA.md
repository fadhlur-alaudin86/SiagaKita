# SiagaKita Database Schema Reference

This document serves as the primary technical specification for the SiagaKita PostgreSQL relational database schema.

---

## Schema Overview

- **Active Version**: Schema v13 (Migrations 001 through 021)
- **Database Engine**: PostgreSQL 15+
- **Driver**: `jackc/pgx/v5` via `pgxpool.Pool` (Raw SQL, ORM-free)
- **Migration Engine**: `golang-migrate` embedded in Go binary
- **Visual Entity-Relationship Diagram**: [`docs/design/database-erd.md`](./design/database-erd.md)

---

## Table of Contents

1. [Database Migration & Reset Procedures](#1-database-migration--reset-procedures)
2. [Domain Data Types & Value Constraints](#2-domain-data-types--value-constraints)
3. [Authentication & Profile Tables](#3-authentication--profile-tables)
4. [Agencies & Responders](#4-agencies--responders)
5. [Incidents & Responses](#5-incidents--responses)
6. [Gamification & Volunteer Reputation](#6-gamification--volunteer-reputation)
7. [Database Triggers](#7-database-triggers)
8. [Entity Relationship Model](#8-entity-relationship-model)
9. [Architecture & Design Rationale](#9-architecture--design-rationale)
10. [Sequential Migration History (001–020)](#10-sequential-migration-history-001020)

---

## 1. Database Migration & Reset Procedures

### In-App Auto-Migration
The backend server (`cmd/api/main.go`) automatically applies all pending UP migrations on startup before binding HTTP and WebSocket ports. Concurrency is safely coordinated across multiple app instances via PostgreSQL advisory locking.

### Migration Management via CLI
The `cmd/migrate` utility manages version transitions locally and inside Docker containers:

```bash
# Check current migration status:
cd backend-go
go run cmd/migrate/main.go status

# Apply all pending UP migrations:
go run cmd/migrate/main.go up

# Rollback the last applied migration:
go run cmd/migrate/main.go down 1

# Force a specific migration version (recovery only):
go run cmd/migrate/main.go force <version>
```

### Complete Database Reset (Development Only)
To reset the development database from scratch:

```bash
# Drop and recreate schema via Docker Compose:
docker compose down -v
docker compose up -d postgres redis

# Run migrations to bring database up to the latest revision:
cd backend-go && go run cmd/migrate/main.go up
```

---

## 2. Domain Data Types & Value Constraints

> [!NOTE]
> As of **Schema v13 (Migration 021)**, all state machine, category, status, role, and relationship columns transitioned from custom PostgreSQL ENUM types to **Domain-Constrained `VARCHAR` with explicit SQL `CHECK` constraints**. This eliminates PostgreSQL migration lockouts (`ALTER TYPE ... ADD VALUE` cannot run inside transaction blocks), ensures 100% transactional safety during zero-downtime deployments via `golang-migrate`, and streamlines model mapping across Go, SQL, Dart, and JSON.

### User Roles (`users.role`)
- **Column**: `varchar(30)` with `CHECK (role IN ('superadmin', 'admin', 'agency', 'agency_personnel', 'volunteer', 'civilian'))`
- `superadmin`: Root platform administrator seeded from environment variables.
- `admin`: Platform administrator (KYC approval, user moderation, ranks management).
- `agency`: Official emergency services organization account (Police, Fire, Medical, SAR).
- `agency_personnel`: Operational field officer tied to a parent agency.
- `volunteer`: Civilian responder verified via KYC.
- `civilian`: General public user.

### Agency Types (`agencies.type`)
- **Column**: `varchar(20)` with `CHECK (type IN ('police', 'fire', 'medical', 'sar'))`
- Categorization of emergency organizations: `police`, `fire`, `medical`, `sar`.

### Blood Types (`user_profiles.blood_type`)
- **Column**: `varchar(10)` with `CHECK (blood_type IN ('A', 'B', 'AB', 'O', 'UNKNOWN', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'))`
- ABO and Rhesus classification. Default is `'UNKNOWN'`.

### Volunteer Certification Status (`volunteer_certifications.status`)
- **Column**: `varchar(20)` with `CHECK (status IN ('pending', 'approved', 'rejected', 'expired'))`
- Credential review lifecycle.

### Incident Types & Categories (`incidents.incident_type`, `incident_reports.incident_type`)
- **Columns**: `varchar(50)` with `CHECK (incident_type IN ('medical', 'fire', 'crime', 'rescue', 'disaster', 'general', 'unknown'))`
- Standardized across both SOS alerts (Jalur A) and community reports (Jalur B).

### SOS Incident Status (`incidents.status` — Jalur A)
- **Column**: `varchar(30)` with `CHECK (status IN ('grace_period', 'broadcasting', 'handling', 'handled', 'resolved', 'false_alarm', 'canceled'))`
- `grace_period`: Initial 10-second cancellation window.
- `broadcasting`: Active SOS alert broadcasted to nearby responders and dispatchers.
- `handling`: Currently being responded to or actively coordinated.
- `handled`: Accepted by a responder or assigned by an emergency agency.
- `resolved`: Handled and marked resolved.
- `false_alarm`: Designated as false alarm with strike logged.
- `canceled`: Canceled by the citizen before responder arrival.

### Agency Handling Status (`incidents.agency_status`)
- **Column**: `varchar(20)` with `CHECK (agency_status IS NULL OR agency_status IN ('pending', 'accepted', 'declined', 'handling', 'completed', 'canceled'))`
- Status of agency coordination for an SOS incident.

### Reporter Trust Label (`incidents.reporter_trust_label`)
- **Column**: `varchar(20)` with `CHECK (reporter_trust_label IS NULL OR reporter_trust_label IN ('standard', 'trusted', 'untrusted', 'verified', 'unverified'))`
- Reputation level assigned dynamically to reporting citizens.

### Community Report Status (`incident_reports.status` — Jalur B)
- **Column**: `varchar(20)` with `CHECK (status IN ('received', 'sent', 'processing', 'investigating', 'handled', 'resolved', 'rejected', 'canceled'))`
- Lifecycle states for non-emergency citizen reports.

### Responder Mission Status (`incident_responses.status`)
- **Column**: `varchar(30)` with `CHECK (status IN ('en_route', 'on_scene', 'waiting_review', 'completed', 'rejected', 'canceled'))`
- Operational lifecycle of a responder assigned to an incident.

### Emergency Contact Relations (`emergency_contacts.relation`)
- **Column**: `varchar(50)` with `CHECK (relation IS NULL OR relation IN ('parent', 'spouse', 'child', 'sibling', 'friend', 'other'))`
- Standardized relationship codes with bilingual client localization (`app_localization.dart`).

---

## 3. Authentication & Profile Tables

### `users` — Authentication Gateway
Stores core authentication credentials and access control roles only. Profile attributes are strictly separated into dedicated tables.

```sql
CREATE TABLE public.users (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    email         varchar(100) NOT NULL UNIQUE,
    password_hash varchar(255) NOT NULL,
    role          user_role NOT NULL DEFAULT 'civilian',
    created_at    timestamptz DEFAULT now() NOT NULL,
    deleted_at    timestamptz
);
```

Indexes: `idx_users_email`, `idx_users_role`, `idx_users_del`

### `user_profiles` — Citizen & Volunteer Profiles
Stores personal, medical, and KYC verification records for `civilian` and `volunteer` accounts. Created atomically with `users` during registration.

```sql
CREATE TABLE public.user_profiles (
    user_id                 uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name               varchar(100),
    nik                     varchar(16) UNIQUE,
    date_of_birth           date,
    place_of_birth          varchar(100),
    phone_number            varchar(20),
    is_email_verified       boolean DEFAULT false,
    is_phone_verified       boolean DEFAULT false,
    is_verified_volunteer   boolean DEFAULT false,
    sos_strike_count        int DEFAULT 0,
    is_sos_banned           boolean DEFAULT false,
    banned_until            timestamptz,
    blood_type              blood_type_enum DEFAULT 'UNKNOWN',
    allergies               text,
    medical_conditions      text,
    height_cm               int CHECK (height_cm > 0),
    weight_kg               int CHECK (weight_kg > 0),
    domicile                text,
    bio                     text,
    kyc_ktp_url             varchar(255),
    profile_photo_url       varchar(255),
    nik_verification_status varchar(20) DEFAULT 'none'
        CHECK (nik_verification_status IN ('none', 'pending', 'approved', 'rejected')),
    fcm_token               text,
    updated_at              timestamptz DEFAULT now()
);
```

Indexes: `idx_up_phone`, `idx_up_nik`, `idx_user_profiles_user_id`, `idx_up_fcm_token`

### `admin_profiles` — Administrator Details
Stores personal records for platform administrators created by superadmin.

```sql
CREATE TABLE public.admin_profiles (
    user_id    uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name  varchar(100),
    created_by uuid REFERENCES users(id),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

### `emergency_contacts` — Personal Emergency Contacts
Stores next-of-kin contacts for civilians, alerted during critical emergencies.

```sql
CREATE TABLE public.emergency_contacts (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id       uuid REFERENCES users(id) ON DELETE CASCADE,
    contact_name  varchar(100) NOT NULL,
    contact_phone varchar(20) NOT NULL,
    relation      varchar(50),
    created_at    timestamptz DEFAULT now(),
    deleted_at    timestamptz
);
```

Indexes: `idx_ec_user`, `idx_emergency_contacts_user_id`

---

## 4. Agencies & Responders

### `agencies` — Emergency Service Organizations
Defines public and private emergency agency headquarters and contact details.

```sql
CREATE TABLE public.agencies (
    id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name           varchar(100) NOT NULL,
    type           agency_type NOT NULL,
    city_code      varchar(50) NOT NULL,
    hotline_number varchar(20),
    latitude       numeric(10,8),
    longitude      numeric(11,8),
    account_id     uuid UNIQUE REFERENCES users(id),
    created_at     timestamptz DEFAULT now()
);
```

Indexes: `idx_agencies_account_id`

### `agency_personnels` — Field Responders
Links field personnel accounts to their respective operating emergency agency.

```sql
CREATE TABLE public.agency_personnels (
    user_id      uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    agency_id    uuid NOT NULL REFERENCES agencies(id) ON DELETE RESTRICT,
    full_name    varchar(100) NOT NULL,
    badge_number varchar(50) NOT NULL UNIQUE,
    is_active    boolean DEFAULT true,
    created_at   timestamptz DEFAULT now()
);
```

Indexes: `idx_ap_agency`, `idx_agency_personnels_agency_id`

---

## 5. Incidents & Responses

### `incidents` — Emergency SOS Alerts (Jalur A)
Stores real-time high-priority emergency alerts triggered by citizens.

```sql
CREATE TABLE public.incidents (
    id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id          uuid REFERENCES users(id),
    incident_type        incident_category NOT NULL DEFAULT 'unknown',
    latitude             numeric(10,8) NOT NULL,
    longitude            numeric(11,8) NOT NULL,
    status               incident_status DEFAULT 'grace_period',
    urgency_level        varchar(10) DEFAULT 'unknown',
    reporter_trust_label varchar(20) DEFAULT 'standard',
    address_detail       varchar(500),
    photo_paths          text[] DEFAULT '{}',
    audio_path           varchar(255),
    handled_by_agency_id uuid REFERENCES public.users(id),
    agency_status        varchar(20) DEFAULT 'pending',
    created_at           timestamptz DEFAULT now() NOT NULL,
    updated_at           timestamptz DEFAULT now(),
    resolved_at          timestamptz
);
```

Indexes: `idx_incidents_reporter`, `idx_incidents_status`, `idx_incidents_created_at`, `idx_incidents_status_created_at`, `idx_incidents_handled_by_agency_id`, `idx_incidents_reporter_id`

### `incident_reports` — Community Reports (Jalur B)
Stores non-critical community incident reports submitted with multi-photo and audio evidence.

```sql
CREATE TABLE public.incident_reports (
    id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    incident_type  varchar(50) NOT NULL,
    urgency_level  smallint,
    latitude       double precision NOT NULL,
    longitude      double precision NOT NULL,
    description    text,
    address_detail varchar(500),
    photo_paths    text[] DEFAULT '{}',
    audio_path     varchar(255),
    status         varchar(20) NOT NULL DEFAULT 'sent',
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    completed_at   timestamptz
);
```

Indexes: `idx_incident_reports_reporter_id`

### `incident_responses` — Responder Mission Tracking
Tracks dispatch missions, responder assignments, arrival timestamps, and completion proof.

```sql
CREATE TABLE public.incident_responses (
    id                 uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    incident_id        uuid REFERENCES incidents(id) ON DELETE CASCADE,
    responder_id       uuid REFERENCES users(id),
    status             response_status DEFAULT 'en_route',
    proof_photo_url    varchar(255),
    responder_lat      numeric(10,8),
    responder_lng      numeric(11,8),
    location_synced_at timestamptz,
    accepted_at        timestamptz DEFAULT now(),
    completed_at       timestamptz,
    UNIQUE (incident_id, responder_id)
);
```

Indexes: `idx_incident_responses_incident_id`, `idx_incident_responses_responder_id`

### `sos_strikes` — Abuse and False Alarm Audit Trail
Logs administrative strike actions against users who abuse emergency SOS triggers.

```sql
CREATE TABLE public.sos_strikes (
    id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
    incident_id uuid REFERENCES incidents(id) ON DELETE SET NULL,
    reason      text,
    marked_by   uuid REFERENCES users(id),
    created_at  timestamptz DEFAULT now()
);
```

Indexes: `idx_sos_strikes_user_id`, `idx_sos_strikes_incident_id`, `idx_sos_strikes_marked_by`

---

## 6. Gamifikasi & Volunteer Reputation

### `m_ranks` — Master Rank Definitions
Stores progression thresholds for volunteer gamification tiers.

```sql
CREATE TABLE public.m_ranks (
    id        serial PRIMARY KEY,
    rank_name varchar(50) NOT NULL,
    min_exp   int NOT NULL,
    icon_url  varchar(255)
);
```

Indexes: `idx_m_ranks_min_exp`

### `m_badges` — Master Badge Definitions
Stores achievements awardable to volunteers upon completing specialized milestones with tiered levels.

```sql
CREATE TABLE public.m_badges (
    id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    badge_code  varchar(50) NOT NULL,
    badge_name  varchar(50) NOT NULL,
    level       int NOT NULL DEFAULT 1,
    threshold   int NOT NULL DEFAULT 1,
    description text,
    icon_url    varchar(255),
    CONSTRAINT uq_m_badges_code_level UNIQUE (badge_code, level)
);
```

Indexes: `idx_m_badges_code_level`, `idx_m_badges_badge_code`

### `volunteer_reputation` — Volunteer Experience & Standing
Records current experience points (XP), active rank, and total rescue missions completed.

```sql
CREATE TABLE public.volunteer_reputation (
    user_id       uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    exp_points    int DEFAULT 0,
    rank_id       int REFERENCES m_ranks(id),
    total_rescues int DEFAULT 0,
    updated_at    timestamptz DEFAULT now()
);
```

Indexes: `idx_volunteer_reputation_rank_id`

### `volunteer_certifications` — Volunteer Verification Documents
Holds certified medical/rescue qualifications uploaded by volunteers for admin KYC review.

```sql
CREATE TABLE public.volunteer_certifications (
    id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id          uuid REFERENCES users(id) ON DELETE CASCADE,
    certificate_type varchar(50) NOT NULL,
    document_url     varchar(255) NOT NULL,
    status           cert_status DEFAULT 'pending',
    verified_by      uuid REFERENCES users(id),
    expires_at       date,
    created_at       timestamptz DEFAULT now()
);
```

Indexes: `idx_volunteer_certifications_user_id`, `idx_volunteer_certifications_verified_by`

### `volunteer_badges_acquired` — Earned Volunteer Badges
Many-to-many relationship mapping earned badges to volunteers.

```sql
CREATE TABLE public.volunteer_badges_acquired (
    id        uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id   uuid REFERENCES users(id) ON DELETE CASCADE,
    badge_id  uuid REFERENCES m_badges(id) ON DELETE CASCADE,
    earned_at timestamptz DEFAULT now(),
    CONSTRAINT uq_volunteer_badges_acquired_user_badge UNIQUE (user_id, badge_id)
);
```

Indexes: `idx_volunteer_badges_acquired_user_id`, `idx_volunteer_badges_acquired_badge_id`, `uq_volunteer_badges_acquired_user_badge`

---

## 7. Database Triggers

### `trg_user_profiles_updated_at`
Automatically updates `updated_at = NOW()` prior to any row modification in `user_profiles`.

### `trg_admin_profiles_updated_at`
Automatically updates `updated_at = NOW()` prior to any row modification in `admin_profiles`.

### `trg_sync_volunteer_verified`
Fires `AFTER UPDATE` on `volunteer_certifications`:
- If `status` transitions to `'approved'`, sets `user_profiles.is_verified_volunteer = true`.
- If `status` transitions away from `'approved'`, checks for remaining approved credentials; if none exist, reverts `is_verified_volunteer = false`.

---

## 8. Entity Relationship Model

```
users (Authentication Gateway)
  ├── user_profiles (Civilian & Volunteer Profiles)
  ├── admin_profiles (Admin & Superadmin Records)
  ├── agency_personnels (Field Responders) ── agencies (Operating Agency)
  ├── emergency_contacts (Personal Next-of-Kin)
  ├── incidents (Emergency SOS Alerts)
  │     └── incident_responses (Dispatched Responders)
  ├── incident_reports (Community Reports)
  ├── sos_strikes (Abuse & False Alarm Audit Log)
  └── volunteer_reputation (Gamification Standing)
        ├── volunteer_certifications (Medical & Rescue Qualifications)
        └── volunteer_badges_acquired ── m_badges (Achievement Badges)
              └── m_ranks (Tier Progression)
```

For the comprehensive interactive Mermaid ERD diagram, see [`docs/design/database-erd.md`](./design/database-erd.md).

---

## 9. Architecture & Design Rationale

1. **Authentication Gateway Isolation**: `users` stores only credentials and security roles. Role-specific attributes reside in discrete tables, preventing sprawling schemas filled with sparse NULL columns.
2. **Denormalized Counters for Performance**: `sos_strike_count` is stored directly on `user_profiles` and updated atomically alongside `sos_strikes`. This allows O(1) permission checks during SOS triggering without aggregating historical rows.
3. **Audit Trail via Soft Deletions**: Sensitive accounts (`users`) and emergency contacts employ `deleted_at` timestamps to preserve investigative history in the event of platform abuse.
4. **Mandatory Foreign Key Indexing**: Migration 019 introduced explicit B-Tree indexes across all 13 relational foreign keys, guaranteeing zero sequential table scans during joins and cascade deletions.
5. **Dual-Driver Coexistence Architecture**: High-frequency, latency-critical read and spatial queries (e.g., `FindNearby` Haversine bounding distance, active volunteer dispatch lookups) execute through native `jackc/pgx/v5` connection pools (`pgxpool.Pool`) and compile-time generated `sqlc` models, eliminating ORM reflection. GORM is retained for standard relational CRUD and schema auto-migrations.

---

## 10. Sequential Migration History (001–022)

| Version | Migration Script | Scope & Description |
|---|---|---|
| `001` | `001_init_schema` | Base schema, extensions (`pgcrypto`), ENUMs, initial tables. |
| `002` | `002_sos_redesign` | Citizen reports restructuring and initial strike counters. |
| `003` | `003_schema_v3` | Slimmed `users` table, decoupled role profile tables. |
| `004` | `004_add_agency_location` | Added `latitude` and `longitude` to `agencies`. |
| `005` | `005_reports_v2` | Multimedia arrays and structured urgency levels on reports. |
| `006` | `006_blood_type_rhesus` | Blood type enumeration expanded with Rhesus factors. |
| `007` | `007_add_bio_and_disaster` | Added `bio` to profiles and `disaster` category to incidents. |
| `008` | `008_incident_enhancements` | Added `canceled` status and multimedia evidence fields to SOS. |
| `009` | `009_kyc_warga` | Identity verification (NIK validation, KTP documents, selfies). |
| `010` | `010_admin_features` | Administrative management features and activity tracking. |
| `011` | `011_drop_phone_unique` | Relaxed strict phone uniqueness to accommodate family devices. |
| `012` | `012_reports_and_volunteer` | Volunteer experience records and report submission triage. |
| `013` | `013_separate_handling` | Multi-agency dispatch separation, proof photos, badges master. |
| `014` | `014_incident_responses_update` | Standardized completion timestamps and `on_scene` status. |
| `015` | `015_response_location` | Added live volunteer GPS coordinates to incident responses. |
| `016` | `016_place_of_birth` | Added `place_of_birth` column to `user_profiles`. |
| `017` | `017_refactor_text_to_varchar` | Standardized unbounded `TEXT` fields to explicit `VARCHAR`. |
| `018` | `018_incident_reports_address...` | Nominatim reverse-geocoded addresses and completion timestamps. |
| `019` | `019_add_missing_fk_indexes` | Added B-Tree indexes across all 13 relational foreign keys. |
| `020` | `020_add_analytics_indexes` | Composite indexes for incident stats and gamification rank queries. |
| `021` | `021_standardize_varchar_constraints_and_relations` | Transitioned custom ENUMs to Domain-Constrained VARCHAR with CHECK constraints; standardized emergency contact relations. |
| `022` | `022_add_multi_level_badges_and_constraints` | Added badge_code, level, and threshold to m_badges with UNIQUE(badge_code, level), added UNIQUE(user_id, badge_id) to volunteer_badges_acquired, and seeded 17 multi-level milestones across 5 categories. |
| `023` | `023_add_fcm_token_to_user_profiles` | Added `fcm_token` column to `user_profiles` and partial index `idx_up_fcm_token` for push notifications delivery. |
