CREATE TYPE incident_category AS ENUM ('medical', 'fire', 'crime', 'rescue', 'general', 'disaster', 'unknown');
CREATE TYPE incident_status AS ENUM ('grace_period', 'broadcasting', 'handled', 'resolved', 'false_alarm', 'canceled');
CREATE TYPE response_status AS ENUM ('en_route', 'on_scene', 'waiting_review', 'completed', 'rejected', 'canceled');

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email varchar(100) NOT NULL UNIQUE
);

CREATE TABLE incidents (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id uuid REFERENCES users(id),
    incident_type incident_category NOT NULL DEFAULT 'unknown',
    latitude numeric(10,8) NOT NULL,
    longitude numeric(11,8) NOT NULL,
    status incident_status DEFAULT 'grace_period',
    urgency_level varchar(10) DEFAULT 'unknown',
    reporter_trust_label varchar(20) DEFAULT 'standard',
    address_detail text,
    photo_paths text[] DEFAULT '{}',
    audio_path text,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now(),
    completed_at timestamptz
);

CREATE TABLE incident_responses (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    incident_id uuid REFERENCES incidents(id) ON DELETE CASCADE,
    responder_id uuid REFERENCES users(id),
    status response_status DEFAULT 'en_route',
    accepted_at timestamptz DEFAULT now(),
    arrived_at timestamptz,
    completed_at timestamptz,
    proof_photo_url varchar(255),
    UNIQUE (incident_id, responder_id)
);
