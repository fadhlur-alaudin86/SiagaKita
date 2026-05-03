-- Migration 005: Reports table upgrade
-- Mengganti kolom photo_url/audio_url (single) ke photo_paths (array) + audio_path
-- dan menyesuaikan kolom urgency ke urgency_level (int)
--
-- Jalankan di VPS:
-- docker exec -i siagakita_postgres psql -U ${DB_USER} -d ${DB_NAME} < migrations/005_reports_v2.sql

-- 1. Buat tabel baru yang menggantikan incident_reports
CREATE TABLE IF NOT EXISTS incident_reports_v2 (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    incident_type VARCHAR(50) NOT NULL,
    urgency_level SMALLINT NOT NULL DEFAULT 1,      -- 0=ringan, 1=sedang, 2=kritis
    latitude      DOUBLE PRECISION NOT NULL,
    longitude     DOUBLE PRECISION NOT NULL,
    description   TEXT,
    photo_paths   TEXT[] DEFAULT '{}',
    audio_path    TEXT,
    status        VARCHAR(20) NOT NULL DEFAULT 'received', -- received, processing, resolved
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Migrasi data lama jika tabel sebelumnya sudah ada
INSERT INTO incident_reports_v2 (id, reporter_id, incident_type, urgency_level, latitude, longitude, description, photo_paths, audio_path, status, created_at, updated_at)
SELECT
    id,
    reporter_id,
    incident_type,
    CASE urgency WHEN 'high' THEN 2 WHEN 'medium' THEN 1 ELSE 0 END,
    latitude,
    longitude,
    description,
    CASE WHEN photo_url IS NOT NULL THEN ARRAY[photo_url] ELSE '{}' END,
    audio_url,
    CASE status WHEN 'actioned' THEN 'resolved' WHEN 'reviewed' THEN 'processing' ELSE 'received' END,
    created_at,
    updated_at
FROM incident_reports
ON CONFLICT DO NOTHING;

-- 3. Rename tabel lama dan baru
ALTER TABLE IF EXISTS incident_reports RENAME TO incident_reports_old;
ALTER TABLE incident_reports_v2 RENAME TO incident_reports;

-- 4. Buat index
CREATE INDEX IF NOT EXISTS idx_incident_reports_reporter_id ON incident_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_incident_reports_created_at ON incident_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_incident_reports_status ON incident_reports(status);
