CREATE OR REPLACE FUNCTION log_booking_event()
RETURNS TRIGGER AS $$
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
      'service_type', NEW.service_type
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
$$ LANGUAGE plpgsql SECURITY DEFINER;;
