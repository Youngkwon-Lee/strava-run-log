-- Update functions referencing renamed columns

-- 1. backfill_encounter_notes: person_id->subject_person_id, expert_id->provider_person_id
CREATE OR REPLACE FUNCTION backfill_encounter_notes(p_limit integer DEFAULT 100)
RETURNS TABLE(enc_id uuid, created boolean, message text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_encounter RECORD;
  v_obs_summary TEXT;
  v_note_id UUID;
BEGIN
  FOR v_encounter IN
    SELECT e.id, e.visit_number, e.session_type, e.chief_complaint,
           e.subject_person_id, e.provider_person_id, e.organization_id, e.period_start
    FROM encounters e
    WHERE e.status = 'finished'
      AND NOT EXISTS (SELECT 1 FROM encounter_notes en WHERE en.encounter_id = e.id)
    ORDER BY e.period_start DESC
    LIMIT p_limit
  LOOP
    SELECT string_agg(
      COALESCE(o.code_display, o.code) || ': ' ||
      COALESCE(o.value_quantity::TEXT || COALESCE(o.value_unit, ''), o.value_string, '-'),
      chr(10)
    )
    INTO v_obs_summary
    FROM (
      SELECT code, code_display, value_quantity, value_string, value_unit
      FROM observations obs
      WHERE obs.encounter_id = v_encounter.id
      ORDER BY obs.created_at
      LIMIT 15
    ) o;

    INSERT INTO encounter_notes (
      encounter_id, organization_id, subject_person_id, provider_person_id,
      note_format, subjective, objective, assessment, plan, status, is_medical_context
    ) VALUES (
      v_encounter.id,
      v_encounter.organization_id,
      v_encounter.subject_person_id,
      v_encounter.provider_person_id,
      'soap',
      COALESCE(v_encounter.chief_complaint, 'Visit #' || COALESCE(v_encounter.visit_number::TEXT, '-') || ' (' || to_char(v_encounter.period_start, 'YYYY-MM-DD') || ')'),
      COALESCE(v_obs_summary, 'No observation data'),
      '[Auto-generated] Assessment review needed',
      '[Auto-generated] Plan review needed',
      'draft',
      false
    )
    RETURNING id INTO v_note_id;

    enc_id := v_encounter.id;
    created := true;
    message := 'Note created: ' || v_note_id::TEXT;
    RETURN NEXT;
  END LOOP;
END;
$fn$;

-- 2. create_encounter_from_completed_booking: person_id->subject_person_id, professional_id->provider_person_id
CREATE OR REPLACE FUNCTION create_encounter_from_completed_booking()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_existing_id UUID;
  v_encounter_id UUID;
  v_actor_id UUID;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    SELECT id INTO v_existing_id FROM encounters WHERE booking_id = NEW.id LIMIT 1;
    IF v_existing_id IS NOT NULL THEN RETURN NEW; END IF;

    INSERT INTO encounters (
      fhir_id, subject_person_id, provider_person_id, organization_id,
      class, session_type, status, period_start, period_end, duration_minutes,
      created_by, booking_id
    ) VALUES (
      'enc-' || extract(epoch from now())::bigint || '-' || substr(gen_random_uuid()::text,1,7),
      NEW.subject_person_id,
      NEW.provider_person_id,
      NEW.organization_id,
      'AMB',
      CASE WHEN NEW.session_type = 'follow_up' THEN 'followup'
           WHEN NEW.session_type = 'assessment' THEN 'initial'
           ELSE 'general' END,
      'in-progress',
      NOW(),
      NOW() + (NEW.duration_minutes || ' minutes')::interval,
      NEW.duration_minutes,
      NEW.provider_person_id,
      NEW.id
    ) RETURNING id INTO v_encounter_id;

    IF NEW.lead_id IS NOT NULL THEN
      UPDATE leads SET status = 'booked', updated_at = NOW()
      WHERE id = NEW.lead_id AND status IN ('new', 'triaged', 'offered', 'accepted');
    END IF;

    SELECT id INTO v_actor_id FROM persons WHERE auth_user_id = auth.uid();
    IF v_actor_id IS NULL THEN v_actor_id := NEW.provider_person_id; END IF;

    INSERT INTO booking_events (id, booking_id, event_type, actor_person_id, actor_type, payload, organization_id, created_at)
    VALUES (gen_random_uuid(), NEW.id, 'ENCOUNTER_CREATED', v_actor_id, 'system',
      jsonb_build_object('encounter_id', v_encounter_id, 'booking_id', NEW.id, 'lead_id', NEW.lead_id, 'lead_status_updated', NEW.lead_id IS NOT NULL),
      NEW.organization_id, NOW());
  END IF;
  RETURN NEW;
END;
$fn$;

-- 3. log_booking_event: person_id->subject_person_id, professional_id->provider_person_id
CREATE OR REPLACE FUNCTION log_booking_event()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_event_type TEXT;
  v_payload JSONB;
  v_actor_id UUID;
  v_actor_type TEXT;
  v_org_id UUID;
BEGIN
  v_org_id := COALESCE(NEW.organization_id, OLD.organization_id);

  SELECT id INTO v_actor_id FROM persons WHERE auth_user_id = auth.uid();
  IF v_actor_id IS NULL THEN
    v_actor_id := COALESCE(NEW.provider_person_id, OLD.provider_person_id);
  END IF;

  IF TG_OP = 'INSERT' THEN
    v_event_type := 'BOOKING_CREATED';
    v_actor_type := CASE WHEN NEW.subject_person_id = v_actor_id THEN 'client' ELSE 'professional' END;
    v_payload := jsonb_build_object(
      'subject_person_id', NEW.subject_person_id,
      'provider_person_id', NEW.provider_person_id,
      'scheduled_at', NEW.scheduled_at,
      'session_type', NEW.session_type
    );
    INSERT INTO booking_events (id, booking_id, event_type, actor_person_id, actor_type, payload, organization_id, created_at)
    VALUES (gen_random_uuid(), NEW.id, v_event_type, v_actor_id, v_actor_type, v_payload, v_org_id, NOW());
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      v_event_type := CASE NEW.status
        WHEN 'confirmed' THEN 'CONFIRMED'
        WHEN 'rejected' THEN 'REJECTED'
        WHEN 'completed' THEN 'COMPLETED'
        WHEN 'cancelled' THEN 'CANCELLED'
        WHEN 'no_show' THEN 'NO_SHOW'
        WHEN 'rescheduled' THEN 'RESCHEDULED'
        ELSE 'STATUS_CHANGED'
      END;
      v_payload := jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status);
    ELSIF OLD.scheduled_at IS DISTINCT FROM NEW.scheduled_at THEN
      v_event_type := 'RESCHEDULED';
      v_payload := jsonb_build_object('old_scheduled_at', OLD.scheduled_at, 'new_scheduled_at', NEW.scheduled_at);
    ELSE
      v_event_type := 'BOOKING_UPDATED';
      v_payload := jsonb_build_object('updated_fields', NULL);
    END IF;
    v_actor_type := CASE WHEN NEW.subject_person_id = v_actor_id THEN 'client' ELSE 'professional' END;
    INSERT INTO booking_events (id, booking_id, event_type, actor_person_id, actor_type, payload, organization_id, created_at)
    VALUES (gen_random_uuid(), NEW.id, v_event_type, v_actor_id, v_actor_type, v_payload, v_org_id, NOW());
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$fn$;;
