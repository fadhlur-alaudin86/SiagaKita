-- 015: Tambah kolom tempat lahir ke user_profiles

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS place_of_birth VARCHAR(100);
