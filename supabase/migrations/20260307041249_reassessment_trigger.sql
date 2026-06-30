
CREATE OR REPLACE FUNCTION trg_check_reassessment_due()
RETURNS TRIGGER AS $$
DECLARE
  v_count INTEGER;
  v_care_person_id UUID;
  v_threshold INTEGER := 10;
  v_existing UUID;
BEGIN
  IF NEW.status = 'finished' AND (OLD.status IS NULL OR OLD.status != 'finished') THEN
    SELECT count(*) INTO v_count
    FROM encounters
    WHERE subject_person_id = NEW.subject_person_id
      AND organization_id = NEW.organization_id
      AND status = 'finished';

    IF v_count > 0 AND v_count % v_threshold = 0 THEN
      SELECT id INTO v_existing
      FROM clinical_tasks
      WHERE subject_person_id = NEW.subject_person_id
        AND organization_id = NEW.organization_id
        AND task_type = 'reassessment_due'
        AND status = 'pending';

      IF v_existing IS NULL THEN
        SELECT provider_person_id INTO v_care_person_id
        FROM care_relationship
        WHERE client_person_id = NEW.subject_person_id
          AND organization_id = NEW.organization_id
          AND is_primary = true
          AND status = 'active'
        LIMIT 1;

        INSERT INTO clinical_tasks (
          organization_id, assigned_to, task_type, priority,
          subject_person_id, due_date, source, context_json
        ) VALUES (
          NEW.organization_id,
          COALESCE(v_care_person_id, NEW.provider_person_id),
          'reassessment_due', 'urgent',
          NEW.subject_person_id, now() + interval '3 days', 'system',
          jsonb_build_object(
            'visit_count', v_count,
            'threshold', v_threshold,
            'last_encounter_id', NEW.id
          )
        );
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_encounter_reassessment_check
  AFTER UPDATE ON encounters
  FOR EACH ROW EXECUTE FUNCTION trg_check_reassessment_due();
;
