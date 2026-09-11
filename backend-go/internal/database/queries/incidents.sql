-- name: FindNearbyIncidents :many
SELECT
    id::text AS id,
    incident_type::text AS incident_type,
    CAST(status AS VARCHAR) AS status,
    latitude::float8 AS latitude,
    longitude::float8 AS longitude,
    address_detail,
    COALESCE(reporter_trust_label, 'unverified')::text AS reporter_trust_label,
    to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
    (
        6371 * acos(
            LEAST(1.0, cos(radians(@lat::float8)) * cos(radians(latitude)) *
            cos(radians(longitude) - radians(@lng::float8)) +
            sin(radians(@lat::float8)) * sin(radians(latitude)))
        )
    )::float8 AS distance_km,
    COALESCE(photo_paths, ARRAY[]::text[])::text[] AS photo_paths,
    audio_path
FROM incidents
WHERE status NOT IN ('resolved', 'false_alarm', 'canceled')
  AND reporter_id != @volunteer_id::uuid
  AND NOT EXISTS (
    SELECT 1 FROM incident_responses ir2
    WHERE ir2.incident_id = incidents.id
      AND ir2.responder_id = @volunteer_id::uuid
      AND ir2.status IN ('waiting_review', 'completed', 'on_scene')
  )
  AND (
    6371 * acos(
        LEAST(1.0, cos(radians(@lat::float8)) * cos(radians(latitude)) *
        cos(radians(longitude) - radians(@lng::float8)) +
        sin(radians(@lat::float8)) * sin(radians(latitude)))
    )
  ) <= @radius_km::float8
ORDER BY distance_km ASC;

-- name: GetActiveResponseByVolunteer :one
SELECT
    ir.id::text       AS response_id,
    i.id::text        AS incident_id,
    i.incident_type::text AS incident_type,
    CAST(ir.status AS VARCHAR) AS status,
    i.latitude::float8  AS reporter_latitude,
    i.longitude::float8 AS reporter_longitude,
    i.address_detail,
    CAST(ir.accepted_at AS VARCHAR) AS accepted_at
FROM incident_responses ir
JOIN incidents i ON i.id = ir.incident_id
WHERE ir.responder_id = @volunteer_id::uuid
  AND ir.status IN ('on_scene', 'waiting_review')
ORDER BY ir.accepted_at DESC
LIMIT 1;
