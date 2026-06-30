INSERT INTO public.ml_model_registry (
  id, organization_id, model_name, version_number, description,
  model_type, config, metrics, status, is_default,
  training_data_start, training_data_end, training_samples,
  deployed_at, deployed_by, created_at, updated_at
)
SELECT
  cmv.id,
  COALESCE(
    (SELECT cp.organization_id FROM public.churn_predictions cp
     WHERE cp.model_version_id = cmv.id LIMIT 1),
    (SELECT o.id FROM public.organizations o LIMIT 1)
  ),
  cmv.model_name,
  cmv.version_number,
  cmv.description,
  cmv.model_type,
  cmv.config,
  jsonb_build_object(
    'accuracy', cmv.validation_accuracy,
    'precision', cmv.precision_score,
    'recall', cmv.recall_score,
    'f1', cmv.f1_score,
    'auc_roc', cmv.auc_roc
  ),
  cmv.status,
  cmv.is_default,
  cmv.training_data_start,
  cmv.training_data_end,
  cmv.training_samples,
  cmv.deployed_at,
  cmv.deployed_by,
  cmv.created_at,
  cmv.updated_at
FROM public.churn_model_versions cmv
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.churn_predictions
  ADD COLUMN IF NOT EXISTS ml_registry_id uuid REFERENCES public.ml_model_registry(id);

UPDATE public.churn_predictions cp
SET ml_registry_id = cp.model_version_id
WHERE cp.ml_registry_id IS NULL
  AND cp.model_version_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_churn_pred_ml_registry
  ON public.churn_predictions (ml_registry_id)
  WHERE ml_registry_id IS NOT NULL;;
