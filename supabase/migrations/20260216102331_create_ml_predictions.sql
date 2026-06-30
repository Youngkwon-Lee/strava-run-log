CREATE TABLE IF NOT EXISTS public.ml_predictions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id     uuid NOT NULL REFERENCES public.organizations(id),
  model_registry_id   uuid NOT NULL REFERENCES public.ml_model_registry(id),
  model_name          text NOT NULL,
  model_version       text NOT NULL,
  subject_person_id   uuid REFERENCES public.persons(id),
  encounter_id        uuid REFERENCES public.encounters(id),
  input_hash          text,
  input_summary       jsonb,
  output              jsonb NOT NULL,
  confidence          numeric(5,4),
  latency_ms          int4,
  feedback_status     text DEFAULT 'pending'
    CHECK (feedback_status IN ('pending','accepted','modified','rejected','expired')),
  feedback_detail     jsonb,
  feedback_by         uuid,
  feedback_at         timestamptz,
  predicted_at        timestamptz NOT NULL DEFAULT now(),
  created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.ml_predictions IS 'Unified prediction log for all ML models';

CREATE INDEX IF NOT EXISTS idx_ml_pred_org_model
  ON public.ml_predictions (organization_id, model_name);

CREATE INDEX IF NOT EXISTS idx_ml_pred_person
  ON public.ml_predictions (subject_person_id)
  WHERE subject_person_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ml_pred_encounter
  ON public.ml_predictions (encounter_id)
  WHERE encounter_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ml_pred_predicted_at
  ON public.ml_predictions (predicted_at DESC);

CREATE INDEX IF NOT EXISTS idx_ml_pred_input_hash
  ON public.ml_predictions (input_hash)
  WHERE input_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ml_pred_feedback
  ON public.ml_predictions (feedback_status)
  WHERE feedback_status != 'pending';

CREATE INDEX IF NOT EXISTS idx_ml_pred_registry
  ON public.ml_predictions (model_registry_id);

ALTER TABLE public.ml_predictions ENABLE ROW LEVEL SECURITY;

CREATE POLICY ml_pred_select_org ON public.ml_predictions
  FOR SELECT USING (is_org_member(organization_id));

CREATE POLICY ml_pred_insert_org ON public.ml_predictions
  FOR INSERT WITH CHECK (is_org_member(organization_id));

CREATE POLICY ml_pred_platform_admin ON public.ml_predictions
  FOR ALL USING (is_platform_admin())
  WITH CHECK (is_platform_admin());;
