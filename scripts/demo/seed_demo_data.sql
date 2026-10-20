-- seed_demo_data.sql - Idempotent demo seeder for the exhibition droplet.
--
-- Purpose: Provide cross-role accounts and sample incidents so the whole SOS
--          chain (civilian -> volunteer -> agency -> field personnel) can be
--          demonstrated end to end.
-- Data & Logic Flow: run after the backend has booted (migration 023 applied).
--          The script is idempotent (fixed UUIDs plus ON CONFLICT DO NOTHING),
--          so re-running it against a fresh droplet is safe.
-- Key Components: 11 demo accounts, 4 agencies, 2 field personnel, 2 verified
--          volunteers, 1 volunteer awaiting KYC review, 6 SOS incidents, and
--          3 civilian reports.
--
-- Important: every still-ACTIVE SOS belongs to the passive reporter account
--          `warga.wati@siagakita.demo`. The backend rejects a new SOS while the
--          reporter has an incident that is not resolved ("SOS sudah aktif"),
--          so `warga.agus` and `warga.dewi` are intentionally left free: an SOS
--          triggered from the civilian app always creates a fresh incident.
--
-- Usage (from the workstation):
--   docker exec -i siagakita_postgres sh -c \
--     'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < scripts/demo/seed_demo_data.sql
--
-- Every demo account uses the shared demo password documented in DEMO_FLOW.md.

-- --- 0. Guard: assert the migrations have been applied ---
DO $$
BEGIN
    IF (SELECT count(*) FROM public.m_badges) = 0 THEN
        RAISE EXCEPTION 'm_badges is empty - the migrations have not been applied. Start the backend first, then re-run this seeder.';
    END IF;
END $$;

BEGIN;

-- --- 1. Shared password hash for every demo account ---
-- bcrypt cost 12, matching the user service; see DEMO_FLOW.md for the password
CREATE TEMP TABLE seed_pw (hash text) ON COMMIT DROP;
INSERT INTO seed_pw (hash) VALUES ('$2a$12$Y7kO18IBfJFnMre45HYItuV6cX2Dxnt/JRAhbQsJlcVgyFnFRnv2W');

-- --- 2. User accounts across roles ---
INSERT INTO public.users (id, email, password_hash, role) VALUES
    ('11111111-1111-4111-8111-000000000001', 'admin@siagakita.demo',          (SELECT hash FROM seed_pw), 'admin'),
    ('11111111-1111-4111-8111-000000000002', 'agensi.medis@siagakita.demo',   (SELECT hash FROM seed_pw), 'agency'),
    ('11111111-1111-4111-8111-000000000003', 'agensi.damkar@siagakita.demo',  (SELECT hash FROM seed_pw), 'agency'),
    ('11111111-1111-4111-8111-000000000004', 'petugas.pmi@siagakita.demo',    (SELECT hash FROM seed_pw), 'agency_personnel'),
    ('11111111-1111-4111-8111-000000000005', 'petugas.damkar@siagakita.demo', (SELECT hash FROM seed_pw), 'agency_personnel'),
    ('11111111-1111-4111-8111-000000000006', 'relawan.budi@siagakita.demo',   (SELECT hash FROM seed_pw), 'volunteer'),
    ('11111111-1111-4111-8111-000000000007', 'relawan.sari@siagakita.demo',   (SELECT hash FROM seed_pw), 'volunteer'),
    ('11111111-1111-4111-8111-000000000008', 'warga.agus@siagakita.demo',     (SELECT hash FROM seed_pw), 'civilian'),
    ('11111111-1111-4111-8111-000000000009', 'warga.dewi@siagakita.demo',     (SELECT hash FROM seed_pw), 'civilian'),
    ('11111111-1111-4111-8111-00000000000a', 'relawan.rina@siagakita.demo',   (SELECT hash FROM seed_pw), 'volunteer'),
    -- Passive reporter that owns every seeded active SOS (see the header note)
    ('11111111-1111-4111-8111-00000000000b', 'warga.wati@siagakita.demo',     (SELECT hash FROM seed_pw), 'civilian')
ON CONFLICT (id) DO NOTHING;

-- --- 3. Admin profile ---
INSERT INTO public.admin_profiles (user_id, full_name) VALUES
    ('11111111-1111-4111-8111-000000000001', 'Admin Operasional SiagaKita')
ON CONFLICT (user_id) DO NOTHING;

-- --- 4. Civilian and volunteer profiles ---
INSERT INTO public.user_profiles (
    user_id, full_name, nik, date_of_birth, phone_number,
    is_email_verified, is_phone_verified, is_verified_volunteer,
    blood_type, allergies, medical_conditions, height_cm, weight_kg,
    domicile, bio, nik_verification_status, volunteer_experience, place_of_birth
) VALUES
    -- Civilians
    ('11111111-1111-4111-8111-000000000008', 'Agus Setiawan', '3273010101900001', '1990-01-01', '6281200000008',
     TRUE, TRUE, FALSE, 'O+', 'Debu', NULL, 172, 68,
     'Jl. Dipatiukur No. 12, Bandung', 'Warga Kota Bandung', 'approved', NULL, 'Bandung'),
    ('11111111-1111-4111-8111-000000000009', 'Dewi Kartika', '3273010202920002', '1992-02-02', '6281200000009',
     TRUE, TRUE, FALSE, 'B+', NULL, 'Asma ringan', 160, 52,
     'Jl. Sukajadi No. 45, Bandung', 'Guru sekolah dasar', 'approved', NULL, 'Cimahi'),
    -- Passive reporter: owns the seeded active SOS, never used for the live trigger demo
    ('11111111-1111-4111-8111-00000000000b', 'Wati Nurhayati', '3273010606970006', '1997-06-06', '6281200000011',
     TRUE, TRUE, FALSE, 'A-', NULL, NULL, 163, 57,
     'Jl. Buah Batu No. 100, Bandung', 'Karyawan swasta', 'approved', NULL, 'Bandung'),
    -- Verified volunteers
    ('11111111-1111-4111-8111-000000000006', 'Budi Santoso', '3273010303880003', '1988-03-03', '6281200000006',
     TRUE, TRUE, TRUE, 'A+', NULL, NULL, 175, 72,
     'Jl. Setiabudi No. 88, Bandung', 'Relawan aktif sejak 2024', 'approved',
     'Relawan tanggap bencana PMI Kota Bandung selama 2 tahun', 'Bandung'),
    ('11111111-1111-4111-8111-000000000007', 'Sari Melati', '3273010404950004', '1995-04-04', '6281200000007',
     TRUE, TRUE, TRUE, 'AB+', 'Seafood', NULL, 165, 55,
     'Jl. Pasteur No. 21, Bandung', 'Perawat komunitas', 'approved',
     'Kader kesehatan komunitas tingkat kelurahan', 'Garut'),
    -- Volunteer awaiting KYC verification (for the console review demo)
    ('11111111-1111-4111-8111-00000000000a', 'Rina Puspita', '3273010505960005', '1996-05-05', '6281200000010',
     TRUE, FALSE, FALSE, 'O-', NULL, NULL, 158, 50,
     'Jl. Cihampelas No. 5, Bandung', 'Mahasiswa keperawatan', 'pending',
     'Anggota palang merah remaja tingkat kota', 'Sumedang')
ON CONFLICT (user_id) DO NOTHING;

-- --- 5. Agencies ---
-- agencies.account_id points at the agency login account (users.id).
INSERT INTO public.agencies (id, name, type, city_code, hotline_number, account_id, latitude, longitude) VALUES
    ('22222222-2222-4222-8222-000000000001', 'PMI Kota Bandung', 'medical', 'BDG', '022-7200001',
     '11111111-1111-4111-8111-000000000002', -6.90250000, 107.61880000),
    ('22222222-2222-4222-8222-000000000002', 'Dinas Kebakaran Kota Bandung', 'fire', 'BDG', '022-7200002',
     '11111111-1111-4111-8111-000000000003', -6.91420000, 107.60950000),
    ('22222222-2222-4222-8222-000000000003', 'Polrestabes Bandung', 'police', 'BDG', '022-7200003',
     NULL, -6.90930000, 107.62110000),
    ('22222222-2222-4222-8222-000000000004', 'Kantor SAR Bandung', 'sar', 'BDG', '022-7200004',
     NULL, -6.92510000, 107.63240000)
ON CONFLICT (id) DO NOTHING;

-- --- 6. Field personnel (journey: mobile-flutter-responder) ---
INSERT INTO public.agency_personnels (user_id, agency_id, full_name, badge_number, is_active) VALUES
    ('11111111-1111-4111-8111-000000000004', '22222222-2222-4222-8222-000000000001', 'Petugas PMI 1001', 'PMI-1001', TRUE),
    ('11111111-1111-4111-8111-000000000005', '22222222-2222-4222-8222-000000000002', 'Petugas Damkar 2001', 'DAMKAR-2001', TRUE)
ON CONFLICT (user_id) DO NOTHING;

-- --- 7. Civilian emergency contacts ---
INSERT INTO public.emergency_contacts (id, user_id, contact_name, contact_phone, relation) VALUES
    ('33333333-3333-4333-8333-000000000001', '11111111-1111-4111-8111-000000000008', 'Siti Rahayu', '6281200000011', 'spouse'),
    ('33333333-3333-4333-8333-000000000002', '11111111-1111-4111-8111-000000000008', 'Rudi Setiawan', '6281200000012', 'sibling')
ON CONFLICT (id) DO NOTHING;

-- --- 8. Volunteer rank master data (this table is not seeded by the migrations) ---
INSERT INTO public.m_ranks (id, rank_name, min_exp, icon_url) VALUES
    (1, 'Pemula', 0, 'rank_pemula'),
    (2, 'Terlatih', 150, 'rank_terlatih'),
    (3, 'Andalan', 600, 'rank_andalan'),
    (4, 'Legenda', 1500, 'rank_legenda')
ON CONFLICT (id) DO NOTHING;
SELECT setval('public.m_ranks_id_seq', GREATEST(4, (SELECT COALESCE(MAX(id), 1) FROM public.m_ranks)));

-- --- 9. Volunteer reputation, certification, and badges ---
INSERT INTO public.volunteer_reputation (user_id, exp_points, rank_id, total_rescues) VALUES
    ('11111111-1111-4111-8111-000000000006', 340, 2, 7),
    ('11111111-1111-4111-8111-000000000007', 90, 1, 2)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.volunteer_certifications (id, user_id, certificate_type, document_url, status, verified_by, expires_at) VALUES
    ('44444444-4444-4444-8444-000000000001', '11111111-1111-4111-8111-000000000006', 'first_aid', 'demo/sertifikat-p3k-budi.pdf', 'approved', '11111111-1111-4111-8111-000000000001', '2027-12-31'),
    ('44444444-4444-4444-8444-000000000002', '11111111-1111-4111-8111-000000000007', 'first_aid', 'demo/sertifikat-p3k-sari.pdf', 'approved', '11111111-1111-4111-8111-000000000001', '2027-12-31')
ON CONFLICT (id) DO NOTHING;

-- Badges are linked by (badge_code, level) because migration 022 generates their ids.
INSERT INTO public.volunteer_badges_acquired (id, user_id, badge_id, earned_at)
SELECT '55555555-5555-4555-8555-000000000001', '11111111-1111-4111-8111-000000000006', b.id, now() - interval '20 days'
  FROM public.m_badges b WHERE b.badge_code = 'first_responder' AND b.level = 1
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.volunteer_badges_acquired (id, user_id, badge_id, earned_at)
SELECT '55555555-5555-4555-8555-000000000002', '11111111-1111-4111-8111-000000000006', b.id, now() - interval '5 days'
  FROM public.m_badges b WHERE b.badge_code = 'community_guardian' AND b.level = 1
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.volunteer_badges_acquired (id, user_id, badge_id, earned_at)
SELECT '55555555-5555-4555-8555-000000000003', '11111111-1111-4111-8111-000000000007', b.id, now() - interval '12 days'
  FROM public.m_badges b WHERE b.badge_code = 'first_responder' AND b.level = 1
ON CONFLICT (id) DO NOTHING;

-- --- 10. Active and historical SOS (path A) ---
-- urgency_level is 'unknown', matching a real SOS triggered from the mobile app.
-- Every ACTIVE row below is reported by the passive reporter account
-- (...00000b) so warga.agus / warga.dewi stay free to trigger SOS during the demo.
INSERT INTO public.incidents (
    id, reporter_id, incident_type, latitude, longitude, status, urgency_level,
    reporter_trust_label, address_detail, created_at, updated_at, completed_at,
    handled_by_agency_id, agency_status
) VALUES
    -- Active SOS awaiting agency dispatch (live map and console alarm)
    ('66666666-6666-4666-8666-000000000001', '11111111-1111-4111-8111-00000000000b', 'medical', -6.90250000, 107.61880000,
     'broadcasting', 'unknown', 'trusted', 'Jl. Dipatiukur No. 12, Bandung (depan kampus)',
     now() - interval '4 minutes', now() - interval '4 minutes', NULL, NULL, 'pending'),
    -- Second SOS so the console map shows several active markers
    ('66666666-6666-4666-8666-000000000002', '11111111-1111-4111-8111-00000000000b', 'disaster', -6.91420000, 107.60950000,
     'broadcasting', 'unknown', 'standard', 'Jl. Sukajadi No. 45, Bandung (genangan tinggi)',
     now() - interval '11 minutes', now() - interval '11 minutes', NULL, NULL, 'pending'),
    -- Being handled by an agency; personnel are already on scene
    ('66666666-6666-4666-8666-000000000003', '11111111-1111-4111-8111-00000000000b', 'fire', -6.90930000, 107.62110000,
     'handling', 'unknown', 'standard', 'Jl. Cihampelas No. 5, Bandung (arus pendek)',
     now() - interval '26 minutes', now() - interval '8 minutes', NULL,
     '11111111-1111-4111-8111-000000000003', 'handling'),
    -- Still inside the grace period (the console shows the cancellation countdown)
    ('66666666-6666-4666-8666-000000000004', '11111111-1111-4111-8111-00000000000b', 'general', -6.92510000, 107.63240000,
     'grace_period', 'unknown', 'standard', 'Jl. Buah Batu No. 100, Bandung',
     now() - interval '25 seconds', now() - interval '25 seconds', NULL, NULL, 'pending'),
    -- Completed history (console statistics)
    ('66666666-6666-4666-8666-000000000005', '11111111-1111-4111-8111-000000000008', 'medical', -6.89470000, 107.61060000,
     'resolved', 'unknown', 'trusted', 'Jl. Setiabudi No. 88, Bandung',
     now() - interval '2 days', now() - interval '2 days' + interval '42 minutes', now() - interval '2 days' + interval '42 minutes',
     '11111111-1111-4111-8111-000000000002', 'completed'),
    -- History cancelled by the reporter
    ('66666666-6666-4666-8666-000000000006', '11111111-1111-4111-8111-000000000009', 'general', -6.93000000, 107.64000000,
     'canceled', 'unknown', 'standard', 'Jl. Kiaracondong No. 7, Bandung',
     now() - interval '5 days', now() - interval '5 days' + interval '40 seconds', NULL, NULL, 'canceled')
ON CONFLICT (id) DO NOTHING;

-- --- 11. Volunteer and personnel responses to SOS ---
INSERT INTO public.incident_responses (
    id, incident_id, responder_id, status, accepted_at, completed_at,
    latitude, longitude, address_detail
) VALUES
    -- Completed mission for volunteer Budi (feeds the gamification statistics)
    ('77777777-7777-4777-8777-000000000001', '66666666-6666-4666-8666-000000000005',
     '11111111-1111-4111-8111-000000000006', 'completed',
     now() - interval '2 days', now() - interval '2 days' + interval '40 minutes',
     -6.89470000, 107.61060000, 'Jl. Setiabudi No. 88, Bandung'),
    -- In-progress mission for volunteer Sari (visible on the console mission board)
    ('77777777-7777-4777-8777-000000000002', '66666666-6666-4666-8666-000000000003',
     '11111111-1111-4111-8111-000000000007', 'on_scene',
     now() - interval '20 minutes', NULL,
     -6.90930000, 107.62110000, 'Jl. Cihampelas No. 5, Bandung')
ON CONFLICT (id) DO NOTHING;

-- --- 12. Civilian non-emergency reports (path B) ---
INSERT INTO public.incident_reports (
    id, reporter_id, incident_type, urgency_level, latitude, longitude,
    description, status, created_at, updated_at, completed_at, address_detail
) VALUES
    ('88888888-8888-4888-8888-000000000001', '11111111-1111-4111-8111-000000000008', 'crime', 2,
     -6.90250000, 107.61880000, 'Percobaan pencurian sepeda motor di depan minimarket, terduga masih di lokasi.',
     'sent', now() - interval '35 minutes', now() - interval '35 minutes', NULL, 'Jl. Dipatiukur No. 20, Bandung'),
    ('88888888-8888-4888-8888-000000000002', '11111111-1111-4111-8111-000000000009', 'general', 1,
     -6.91420000, 107.60950000, 'Lampu penerangan jalan mati sejak dua malam, rawan bagi pengendara.',
     'processing', now() - interval '3 hours', now() - interval '2 hours', NULL, 'Jl. Sukajadi No. 45, Bandung'),
    ('88888888-8888-4888-8888-000000000003', '11111111-1111-4111-8111-000000000008', 'medical', 0,
     -6.89470000, 107.61060000, 'Pengendara motor jatuh ringan, sudah ditangani warga sekitar.',
     'resolved', now() - interval '3 days', now() - interval '3 days' + interval '55 minutes',
     now() - interval '3 days' + interval '55 minutes', 'Jl. Setiabudi No. 88, Bandung')
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- --- 13. Verification summary ---
\echo '--- Demo accounts ---'
SELECT email, role FROM public.users WHERE email LIKE '%@siagakita.demo' ORDER BY role, email;

\echo '--- Agencies ---'
SELECT name, type, (account_id IS NOT NULL) AS has_login_account FROM public.agencies ORDER BY type;

\echo '--- Field personnel ---'
SELECT badge_number, full_name FROM public.agency_personnels ORDER BY badge_number;

\echo '--- SOS incidents by status ---'
SELECT status, count(*) FROM public.incidents GROUP BY status ORDER BY status;

\echo '--- Civilian reports by status ---'
SELECT status, count(*) FROM public.incident_reports GROUP BY status ORDER BY status;
