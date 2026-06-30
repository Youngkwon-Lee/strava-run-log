ALTER TABLE public.model_performance_logs
  ADD COLUMN IF NOT EXISTS model_registry_id uuid REFERENCES public.ml_model_registry(id),
  ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id),
  ADD COLUMN IF NOT EXISTS drift_metrics jsonb;

CREATE INDEX IF NOT EXISTS idx_mpl_registry
  ON public.model_performance_logs (model_registry_id)
  WHERE model_registry_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mpl_org
  ON public.model_performance_logs (organization_id)
  WHERE organization_id IS NOT NULL;

CREATE POLICY mpl_select_org ON public.model_performance_logs
  FOR SELECT USING (
    organization_id IS NULL
    OR is_org_member(organization_id)
  );;
