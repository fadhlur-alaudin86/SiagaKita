-- Migration: Add completed_at and address_detail to incident_reports

ALTER TABLE incident_reports 
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS address_detail VARCHAR(500) NULL;
