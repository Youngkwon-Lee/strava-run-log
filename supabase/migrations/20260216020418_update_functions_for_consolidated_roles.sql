-- 1. get_available_staff: clinician/trainer/staff → provider/staff
CREATE OR REPLACE FUNCTION public.get_available_staff(
  p_organization_id uuid,
  p_date date,
  p_start_time time without time zone,
  p_end_time time without time zone
)
RETURNS TABLE(person_id uuid, person_name text, is_available boolean, has_time_off boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    om.person_id,
    p.display_name AS person_name,
    EXISTS (
      SELECT 1 FROM staff_availability_patterns sap
      WHERE sap.person_id = om.person_id
        AND sap.organization_id = p_organization_id
        AND sap.day_of_week = EXTRACT(DOW FROM p_date)
        AND sap.start_time <= p_start_time
        AND sap.end_time >= p_end_time
        AND sap.effective_from <= p_date
        AND (sap.effective_until IS NULL OR sap.effective_until >= p_date)
        AND sap.deleted_at IS NULL
    ) AS is_available,
    EXISTS (
      SELECT 1 FROM time_off_requests tor
      WHERE tor.person_id = om.person_id
        AND tor.organization_id = p_organization_id
        AND tor.status = 'approved'
        AND p_date BETWEEN tor.start_date AND tor.end_date
        AND tor.deleted_at IS NULL
    ) AS has_time_off
  FROM organization_members om
  JOIN persons p ON p.id = om.person_id
  WHERE om.organization_id = p_organization_id
    AND om.role IN ('provider', 'staff')
  ORDER BY p.display_name;
END;
$function$;

-- 2. infer_expert_type: rewrite to use provider role + org_provider_profile
CREATE OR REPLACE FUNCTION public.infer_expert_type(p_person persons)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_provider_type TEXT;
BEGIN
  -- Check if person is a provider in any org
  SELECT opp.provider_type INTO v_provider_type
  FROM org_provider_profile opp
  JOIN organization_members om ON om.person_id = opp.person_id
    AND om.organization_id = opp.organization_id
  WHERE opp.person_id = p_person.id
    AND om.role = 'provider'
  LIMIT 1;

  IF v_provider_type IS NULL THEN
    -- Fallback: check if they have provider role at all
    IF EXISTS (
      SELECT 1 FROM organization_members
      WHERE person_id = p_person.id AND role = 'provider'
    ) THEN
      -- Infer from care_context
      RETURN CASE
        WHEN p_person.additional_info->>'practice_setting' = 'hospital' THEN 'medical_pt'
        ELSE 'wellness_pt'
      END;
    ELSE
      RETURN NULL;
    END IF;
  END IF;

  -- Map provider_type to expert_type
  RETURN CASE v_provider_type
    WHEN 'clinician' THEN
      CASE WHEN p_person.additional_info->>'practice_setting' = 'hospital'
        THEN 'medical_pt' ELSE 'wellness_pt' END
    WHEN 'trainer' THEN 'trainer'
    WHEN 'pilates_instructor' THEN 'trainer'
    WHEN 'exercise_specialist' THEN 'trainer'
    WHEN 'psychologist' THEN 'expert'
    WHEN 'speech_therapist' THEN 'expert'
    WHEN 'occupational_therapist' THEN 'expert'
    WHEN 'wellness_coach' THEN 'wellness_pt'
    WHEN 'researcher' THEN 'expert'
    ELSE 'wellness_pt'
  END;
END;
$function$;

COMMENT ON FUNCTION infer_expert_type(persons) IS 'Infers expert type from org_provider_profile.provider_type. Falls back to practice_setting if no profile exists.';;
