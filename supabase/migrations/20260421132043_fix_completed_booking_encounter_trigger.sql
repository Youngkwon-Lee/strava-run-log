CREATE OR REPLACE FUNCTION public.create_encounter_from_completed_booking()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_existing_id uuid;
  v_encounter_id uuid;
  v_actor_id uuid;
  v_service_domain text;
  v_encounter_class text;
  v_period_start timestamptz;
  v_period_end timestamptz;
BEGIN
  IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' THEN
    SELECT id INTO v_existing_id
    FROM public.encounters
    WHERE booking_id = NEW.id
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      RETURN NEW;
    END IF;

    v_service_domain := CASE
      WHEN NEW.service_type = 'wellness' THEN 'wellness'
      WHEN NEW.service_type IN ('personal_training', 'group_class') THEN 'fitness'
      ELSE 'clinical'
    END;

    v_encounter_class := CASE
      WHEN NEW.service_type = 'wellness' THEN 'wellness'
      WHEN NEW.service_type IN ('personal_training', 'group_class') THEN 'training'
      ELSE 'AMB'
    END;

    v_period_start := COALESCE(NEW.completed_at, NEW.scheduled_at, NOW());
    v_period_end := v_period_start + make_interval(mins => COALESCE(NEW.duration_minutes, 60));

    INSERT INTO public.encounters (
      fhir_id,
      subject_person_id,
      provider_person_id,
      organization_id,
      class,
      session_type,
      status,
      period_start,
      period_end,
      duration_minutes,
      created_by,
      booking_id,
      service_domain
    ) VALUES (
      'enc-' || extract(epoch from now())::bigint || '-' || substr(gen_random_uuid()::text, 1, 7),
      NEW.subject_person_id,
      NEW.provider_person_id,
      NEW.organization_id,
      v_encounter_class,
      'general',
      'finished',
      v_period_start,
      v_period_end,
      NEW.duration_minutes,
      NEW.provider_person_id,
      NEW.id,
      v_service_domain
    ) RETURNING id INTO v_encounter_id;

    IF NEW.lead_id IS NOT NULL THEN
      UPDATE public.leads
      SET status = 'booked', updated_at = NOW()
      WHERE id = NEW.lead_id
        AND status IN ('new', 'triaged', 'offered', 'accepted');
    END IF;

    SELECT id INTO v_actor_id
    FROM public.persons
    WHERE auth_user_id = auth.uid();

    IF v_actor_id IS NULL THEN
      v_actor_id := NEW.provider_person_id;
    END IF;

    INSERT INTO public.booking_events (
      id,
      booking_id,
      event_type,
      actor_person_id,
      actor_type,
      payload,
      organization_id,
      created_at
    ) VALUES (
      gen_random_uuid(),
      NEW.id,
      'ENCOUNTER_CREATED',
      v_actor_id,
      'system',
      jsonb_build_object(
        'encounter_id', v_encounter_id,
        'booking_id', NEW.id,
        'lead_id', NEW.lead_id,
        'lead_status_updated', NEW.lead_id IS NOT NULL,
        'service_domain', v_service_domain,
        'encounter_class', v_encounter_class
      ),
      NEW.organization_id,
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$function$;
