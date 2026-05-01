-- ============================================================
-- SIAGAKITA — Migration v4
-- Menambahkan atribut latitude dan longitude pada tabel agencies
-- untuk menyimpan lokasi akurat kantor instansi (polisi, damkar, rs).
-- ============================================================

ALTER TABLE public.agencies
ADD COLUMN IF NOT EXISTS latitude numeric(10,8),
ADD COLUMN IF NOT EXISTS longitude numeric(11,8);

-- Catatan: kolom ini opsional (nullable) agar data lama tidak error,
-- tetapi disarankan untuk diisi pada endpoint pembuatan/update instansi.
