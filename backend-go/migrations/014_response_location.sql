-- 014: Tambah kolom lokasi ke incident_responses untuk broadcast posisi relawan

ALTER TABLE incident_responses
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS address_detail TEXT;
