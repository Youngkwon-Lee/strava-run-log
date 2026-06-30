
-- =============================================================================
-- Prompt Evaluation Dataset — AI regression test infrastructure
-- Enables: prompt change → evaluation run → score comparison
-- =============================================================================

CREATE TABLE prompt_evaluation_samples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_name TEXT NOT NULL,           -- matches prompt_templates.name
  input JSONB NOT NULL,                  -- test input (encounter context, observations, etc.)
  expected_output TEXT NOT NULL,          -- gold standard output
  evaluation_criteria JSONB DEFAULT '{}', -- rubric: { completeness: 0.3, accuracy: 0.5, tone: 0.2 }
  tags TEXT[] DEFAULT '{}',              -- e.g., ['soap', 'lumbar', 'complex']
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES persons(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE prompt_evaluation_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_name TEXT NOT NULL,
  template_version INTEGER NOT NULL,
  model TEXT NOT NULL,                   -- e.g., 'gemini-2.5-flash'
  total_samples INTEGER NOT NULL DEFAULT 0,
  avg_score NUMERIC(4,3),               -- 0.000 ~ 1.000
  scores_breakdown JSONB DEFAULT '{}',   -- { completeness: 0.85, accuracy: 0.92, tone: 0.78 }
  latency_p50_ms INTEGER,
  latency_p95_ms INTEGER,
  total_tokens INTEGER,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  error_message TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE prompt_evaluation_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id UUID NOT NULL REFERENCES prompt_evaluation_runs(id) ON DELETE CASCADE,
  sample_id UUID NOT NULL REFERENCES prompt_evaluation_samples(id),
  actual_output TEXT NOT NULL,
  score NUMERIC(4,3) NOT NULL,           -- 0.000 ~ 1.000
  score_details JSONB DEFAULT '{}',      -- per-criterion scores
  latency_ms INTEGER,
  token_usage JSONB DEFAULT '{}',        -- { input: 150, output: 300 }
  evaluator_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_eval_samples_template ON prompt_evaluation_samples(template_name) WHERE is_active;
CREATE INDEX idx_eval_runs_template ON prompt_evaluation_runs(template_name, template_version);
CREATE INDEX idx_eval_results_run ON prompt_evaluation_results(run_id);

-- RLS
ALTER TABLE prompt_evaluation_samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE prompt_evaluation_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE prompt_evaluation_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Platform admins manage eval samples"
  ON prompt_evaluation_samples FOR ALL
  USING (is_platform_admin());

CREATE POLICY "Platform admins manage eval runs"
  ON prompt_evaluation_runs FOR ALL
  USING (is_platform_admin());

CREATE POLICY "Platform admins manage eval results"
  ON prompt_evaluation_results FOR ALL
  USING (is_platform_admin());

-- Service role bypass for AI pipeline
CREATE POLICY "Service role full access on eval samples"
  ON prompt_evaluation_samples FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on eval runs"
  ON prompt_evaluation_runs FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on eval results"
  ON prompt_evaluation_results FOR ALL
  USING (auth.role() = 'service_role');
;
