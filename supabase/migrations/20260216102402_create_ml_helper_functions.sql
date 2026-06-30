CREATE OR REPLACE FUNCTION public.get_active_model(
  p_model_name text,
  p_org_id uuid
) RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT id FROM public.ml_model_registry
  WHERE model_name = p_model_name
    AND organization_id = p_org_id
    AND status = 'active'
    AND is_default = true
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.get_active_model(text, uuid) IS 'Returns the active default model ID for a given model name and org';


CREATE OR REPLACE FUNCTION public.record_ml_prediction(
  p_org_id uuid,
  p_model_name text,
  p_output jsonb,
  p_subject_person_id uuid DEFAULT NULL,
  p_encounter_id uuid DEFAULT NULL,
  p_input_hash text DEFAULT NULL,
  p_input_summary jsonb DEFAULT NULL,
  p_confidence numeric DEFAULT NULL,
  p_latency_ms int4 DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_model public.ml_model_registry%ROWTYPE;
  v_pred_id uuid;
BEGIN
  SELECT * INTO v_model
  FROM public.ml_model_registry
  WHERE model_name = p_model_name
    AND organization_id = p_org_id
    AND status = 'active'
    AND is_default = true
  LIMIT 1;

  IF v_model.id IS NULL THEN
    RAISE EXCEPTION 'No active default model found for % in org %', p_model_name, p_org_id;
  END IF;

  INSERT INTO public.ml_predictions (
    organization_id, model_registry_id, model_name, model_version,
    subject_person_id, encounter_id, input_hash, input_summary,
    output, confidence, latency_ms
  ) VALUES (
    p_org_id, v_model.id, p_model_name, v_model.version_number,
    p_subject_person_id, p_encounter_id, p_input_hash, p_input_summary,
    p_output, p_confidence, p_latency_ms
  ) RETURNING id INTO v_pred_id;

  RETURN v_pred_id;
END;
$$;

COMMENT ON FUNCTION public.record_ml_prediction(uuid, text, jsonb, uuid, uuid, text, jsonb, numeric, int4) IS 'Record a prediction from Cloud Run, auto-resolving active model';


CREATE OR REPLACE FUNCTION public.record_prediction_feedback(
  p_prediction_id uuid,
  p_status text,
  p_detail jsonb DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF p_status NOT IN ('accepted','modified','rejected','expired') THEN
    RAISE EXCEPTION 'Invalid feedback status: %', p_status;
  END IF;

  UPDATE public.ml_predictions
  SET feedback_status = p_status,
      feedback_detail = COALESCE(p_detail, feedback_detail),
      feedback_by = auth.uid(),
      feedback_at = now()
  WHERE id = p_prediction_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prediction not found: %', p_prediction_id;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.record_prediction_feedback(uuid, text, jsonb) IS 'Record clinician feedback on a prediction';


CREATE OR REPLACE FUNCTION public.activate_model_version(
  p_model_id uuid
) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_model public.ml_model_registry%ROWTYPE;
BEGIN
  SELECT * INTO v_model FROM public.ml_model_registry WHERE id = p_model_id;

  IF v_model.id IS NULL THEN
    RAISE EXCEPTION 'Model not found: %', p_model_id;
  END IF;

  UPDATE public.ml_model_registry
  SET status = 'archived',
      is_default = false,
      updated_by = auth.uid(),
      updated_at = now()
  WHERE organization_id = v_model.organization_id
    AND model_name = v_model.model_name
    AND is_default = true
    AND id != p_model_id;

  UPDATE public.ml_model_registry
  SET status = 'active',
      is_default = true,
      deployed_at = now(),
      deployed_by = auth.uid(),
      updated_by = auth.uid(),
      updated_at = now()
  WHERE id = p_model_id;
END;
$$;

COMMENT ON FUNCTION public.activate_model_version(uuid) IS 'Activate a model version, auto-archiving the previous default';;
