-- ============================================
-- Migration: improve_ml_schema
-- Purpose: Fix legacy patterns + fill gaps in ML infra
-- ============================================

-- ===========================================
-- 1. ml_patient_exercise_progress: patient_id(int) → person_id(uuid)
-- ===========================================
DROP POLICY IF EXISTS ml_patient_exercise_progress_insert ON ml_patient_exercise_progress;
DROP POLICY IF EXISTS mlpep_modify ON ml_patient_exercise_progress;
DROP POLICY IF EXISTS mlpep_select ON ml_patient_exercise_progress;

ALTER TABLE ml_patient_exercise_progress
  DROP CONSTRAINT IF EXISTS ml_patient_exercise_progress_patient_id_exercise_name_key;

ALTER TABLE ml_patient_exercise_progress
  DROP COLUMN IF EXISTS patient_id;

ALTER TABLE ml_patient_exercise_progress
  ADD COLUMN person_id uuid NOT NULL REFERENCES persons(id),
  ADD COLUMN organization_id uuid NOT NULL REFERENCES organizations(id);

ALTER TABLE ml_patient_exercise_progress
  ADD CONSTRAINT mlpep_person_exercise_unique UNIQUE (person_id, exercise_name);

CREATE INDEX idx_mlpep_person ON ml_patient_exercise_progress(person_id);
CREATE INDEX idx_mlpep_org ON ml_patient_exercise_progress(organization_id);

-- Restore RLS policies with org-scoped access
CREATE POLICY mlpep_select ON ml_patient_exercise_progress
  FOR SELECT USING (
    organization_id IN (
      SELECT om.organization_id FROM organization_members om
      JOIN persons p ON om.person_id = p.id
      WHERE p.auth_user_id = auth.uid()
    )
  );

CREATE POLICY mlpep_modify ON ml_patient_exercise_progress
  FOR ALL USING (is_platform_admin())
  WITH CHECK (is_platform_admin());

-- ===========================================
-- 2. mlops_events: patient_id(varchar) → person_id(uuid)
-- ===========================================
DROP INDEX IF EXISTS idx_mlops_events_patient;

ALTER TABLE mlops_events
  DROP COLUMN IF EXISTS patient_id;

ALTER TABLE mlops_events
  ADD COLUMN person_id uuid REFERENCES persons(id);

CREATE INDEX idx_mlops_events_person ON mlops_events(person_id);

-- ===========================================
-- 3. Create model_performance_logs (was missing)
-- ===========================================
CREATE TABLE IF NOT EXISTS model_performance_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id text NOT NULL,
  model_version_id uuid REFERENCES churn_model_versions(id),
  accuracy numeric,
  precision_score numeric,
  recall_score numeric,
  f1_score numeric,
  auc_roc numeric,
  sample_count integer,
  evaluation_dataset text,
  metadata jsonb DEFAULT '{}'::jsonb,
  timestamp timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE model_performance_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY mpl_admin_read ON model_performance_logs
  FOR SELECT USING (is_platform_admin());

CREATE POLICY mpl_service ON model_performance_logs
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE INDEX idx_mpl_model ON model_performance_logs(model_id, timestamp DESC);
CREATE INDEX idx_mpl_version ON model_performance_logs(model_version_id);
CREATE INDEX idx_mpl_timestamp ON model_performance_logs(timestamp DESC);

-- ===========================================
-- 4. Fix record_churn_intervention: simplify intervened_by
-- ===========================================
CREATE OR REPLACE FUNCTION record_churn_intervention(
  p_prediction_id uuid,
  p_status text,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE churn_predictions
  SET
    intervention_status = p_status,
    intervention_notes = COALESCE(p_notes, intervention_notes),
    intervened_at = CASE WHEN p_status != 'pending' THEN now() ELSE intervened_at END,
    intervened_by = auth.uid(),
    updated_at = now()
  WHERE id = p_prediction_id;
END;
$$;

-- ===========================================
-- 5. vector_search: IVFFlat → HNSW upgrade
-- ===========================================
DROP INDEX IF EXISTS idx_vector_search_embedding;

CREATE INDEX idx_vector_search_embedding_hnsw
  ON vector_search
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- Add comments for documentation
COMMENT ON TABLE model_performance_logs IS 'ML model performance tracking for monitoring and A/B comparison';
COMMENT ON TABLE ml_patient_exercise_progress IS 'Patient exercise progress tracked by ML analysis (person_id based)';
COMMENT ON TABLE mlops_events IS 'MLOps workflow event log with idempotency (person_id based)';
COMMENT ON INDEX idx_vector_search_embedding_hnsw IS 'HNSW index for cosine similarity vector search (upgraded from IVFFlat)';;
