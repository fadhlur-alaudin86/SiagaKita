-- Name: blood_type_enum; Type: TYPE; Schema: public
-- Menambahkan rhesus factor ke enum golongan darah yang sudah ada

ALTER TYPE public.blood_type_enum ADD VALUE IF NOT EXISTS 'A+';
ALTER TYPE public.blood_type_enum ADD VALUE IF NOT EXISTS 'A-';
ALTER TYPE public.blood_type_enum ADD VALUE IF NOT EXISTS 'B+';
ALTER TYPE public.blood_type_enum ADD VALUE IF NOT EXISTS 'B-';
ALTER TYPE public.blood_type_enum ADD VALUE IF NOT EXISTS 'AB+';
ALTER TYPE public.blood_type_enum ADD VALUE IF NOT EXISTS 'AB-';
ALTER TYPE public.blood_type_enum ADD VALUE IF NOT EXISTS 'O+';
ALTER TYPE public.blood_type_enum ADD VALUE IF NOT EXISTS 'O-';
