-- Migration 011: Volunteer Experience and Report status
-- 1. Tambahkan kolom volunteer_experience di user_profiles
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS volunteer_experience TEXT;

-- 2. Ubah constraint default dari kolom status tabel incident_reports
-- Pertama, jika tabelnya sudah berubah menjadi incident_reports dari incident_reports_v2 (005_reports_v2.sql)
ALTER TABLE incident_reports ALTER COLUMN status SET DEFAULT 'sent';

-- 3. Hilangkan NOT NULL constraint pada urgency_level di incident_reports
ALTER TABLE incident_reports ALTER COLUMN urgency_level DROP NOT NULL;
ALTER TABLE incident_reports ALTER COLUMN urgency_level SET DEFAULT 1;

-- Update data status lama (received -> sent)
UPDATE incident_reports SET status = 'sent' WHERE status = 'received';
