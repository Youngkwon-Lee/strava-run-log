CREATE TABLE IF NOT EXISTS public.ml_model_registry (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id   uuid NOT NULL REFERENCES public.organizations(id),
  model_name        text NOT NULL,
  version_number    text NOT NULL,
  description       text,
  model_type        text NOT NULL,
  config            jsonb NOT NULL DEFAULT '{}'::jsonb,
  metrics           jsonb DEFAULT '{}'::jsonb,
  status            text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','training','validating','active','shadow','archived','deprecated')),
  is_default        boolean NOT NULL DEFAULT false,
  artifact_uri      text,
  input_schema      jsonb,
  output_schema     jsonb,
  parent_model_id   uuid REFERENCES public.ml_model_registry(id),
  training_data_start date,
  training_data_end   date,
  training_samples    int4,
  deployed_at       timestamptz,
  deployed_by       uuid,
  created_by        uuid,
  updated_by        uuid,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.ml_model_registry IS 'Unified ML model registry for all 9+ models';

CREATE UNIQUE INDEX IF NOT EXISTS idx_ml_registry_single_default
  ON public.ml_model_registry (organization_id, model_name)
  WHERE is_default = true;

CREATE INDEX IF NOT EXISTS idx_ml_registry_org_model
  ON public.ml_model_registry (organization_id, model_name);

CREATE INDEX IF NOT EXISTS idx_ml_registry_status
  ON public.ml_model_registry (status);

CREATE INDEX IF NOT EXISTS idx_ml_registry_model_name
  ON public.ml_model_registry (model_name, status);

CREATE INDEX IF NOT EXISTS idx_ml_registry_parent
  ON public.ml_model_registry (parent_model_id)
  WHERE parent_model_id IS NOT NULL;

CREATE TRIGGER set_ml_model_registry_updated_at
  BEFORE UPDATE ON public.ml_model_registry
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.ml_model_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY ml_registry_select_org ON public.ml_model_registry
  FOR SELECT USING (is_org_member(organization_id));

CREATE POLICY ml_registry_manage_admin ON public.ml_model_registry
  FOR ALL USING (is_org_admin(organization_id))
  WITH CHECK (is_org_admin(organization_id));

CREATE POLICY ml_registry_platform_admin ON public.ml_model_registry
  FOR ALL USING (is_platform_admin())
  WITH CHECK (is_platform_admin());;
