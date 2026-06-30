
CREATE OR REPLACE VIEW v_class_analytics AS
SELECT
  b.organization_id,
  b.subject_person_id AS client_id,
  b.provider_person_id AS coach_id,
  p.first_name || ' ' || p.last_name AS client_name,
  COUNT(*) FILTER (WHERE b.status IN ('completed', 'checked_in')) AS attended,
  COUNT(*) AS total_booked,
  ROUND(
    COUNT(*) FILTER (WHERE b.status IN ('completed', 'checked_in'))::numeric
    / NULLIF(COUNT(*), 0) * 100,
    1
  ) AS completion_rate,
  MAX(b.scheduled_at) AS last_session_at,
  MIN(b.scheduled_at) AS first_session_at,
  b.service_type
FROM bookings b
JOIN persons p ON b.subject_person_id = p.id
WHERE b.service_type IN ('group_class', 'wellness', 'coaching', 'personal_training')
GROUP BY
  b.organization_id,
  b.subject_person_id,
  b.provider_person_id,
  p.first_name,
  p.last_name,
  b.service_type;
;
