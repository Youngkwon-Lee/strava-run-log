CREATE OR REPLACE VIEW public.v_churn_predictions_unified AS
SELECT
  p.id,
  p.person_id,
  p.organization_id,
  p.risk_score,
  p.risk_level,
  p.risk_factors,
  p.model_version_id,
  p.ml_registry_id,
  r.model_name,
  r.version_number AS model_version,
  r.status AS model_status,
  p.predicted_at,
  p.created_at,
  'churn_predictions' AS source_table
FROM public.churn_predictions p
LEFT JOIN public.ml_model_registry r ON r.id = COALESCE(p.ml_registry_id, p.model_version_id)
UNION ALL
SELECT
  mp.id,
  mp.subject_person_id AS person_id,
  mp.organization_id,
  (mp.output->>'risk_score')::int4 AS risk_score,
  mp.output->>'risk_level' AS risk_level,
  mp.output->'risk_factors' AS risk_factors,
  NULL::uuid AS model_version_id,
  mp.model_registry_id AS ml_registry_id,
  mp.model_name,
  mp.model_version,
  'active' AS model_status,
  mp.predicted_at,
  mp.created_at,
  'ml_predictions' AS source_table
FROM public.ml_predictions mp
WHERE mp.model_name = 'churn';

COMMENT ON VIEW public.v_churn_predictions_unified IS 'Backward-compatible view combining churn_predictions and ml_predictions for churn model';;
