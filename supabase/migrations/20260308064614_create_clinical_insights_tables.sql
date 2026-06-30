
-- ============================================================================
-- Phase 3: Clinical Insights Panel with Explanation & Feedback Loop
-- Tables: clinical_insights + clinical_insights_feedback
-- ============================================================================

-- Table 1: clinical_insights (Immutable audit log)
CREATE TABLE IF NOT EXISTS clinical_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inference_id UUID NOT NULL REFERENCES ai_inference_log(id) ON DELETE CASCADE,
  encounter_id UUID REFERENCES encounters(id) ON DELETE CASCADE,

  -- Insight type & source
  insight_type TEXT NOT NULL CHECK (insight_type IN (
    'recommended_diagnosis',
    'recommended_special_test',
    'recommended_assessment',
    'recommended_exercise'
  )),
  source_data_type TEXT NOT NULL CHECK (source_data_type IN (
    'vector_search',
    'context_builder',
    'risk_engine'
  )),

  -- What was recommended
  source_id VARCHAR(255),
  source_name VARCHAR(255),
  source_code VARCHAR(100),

  -- Why it was recommended
  explanation TEXT,
  confidence NUMERIC(3, 0) CHECK (confidence >= 0 AND confidence <= 100),

  -- Related clinical evidence
  related_trend_id UUID,
  related_flag_id UUID,
  related_previous_soap_id UUID,

  -- Metadata
  query_text VARCHAR(500),
  similarity_score NUMERIC(3, 2) CHECK (similarity_score >= 0 AND similarity_score <= 1),
  keyword_match_score NUMERIC(3, 2) CHECK (keyword_match_score >= 0 AND keyword_match_score <= 1),

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES persons(id) ON DELETE SET NULL,

  -- Track which organization this insight belongs to (via encounter or inference log)
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE
);

-- Indexes for clinical_insights
CREATE INDEX idx_clinical_insights_inference_id ON clinical_insights(inference_id);
CREATE INDEX idx_clinical_insights_encounter_id ON clinical_insights(encounter_id);
CREATE INDEX idx_clinical_insights_organization_id ON clinical_insights(organization_id);
CREATE INDEX idx_clinical_insights_insight_type ON clinical_insights(insight_type);
CREATE INDEX idx_clinical_insights_created_at ON clinical_insights(created_at DESC);

-- Table 2: clinical_insights_feedback (Immutable learning log)
CREATE TABLE IF NOT EXISTS clinical_insights_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  insight_id UUID NOT NULL REFERENCES clinical_insights(id) ON DELETE CASCADE,

  -- Reviewer & context
  reviewer_person_id UUID NOT NULL REFERENCES persons(id) ON DELETE RESTRICT,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

  -- Feedback action
  action TEXT NOT NULL CHECK (action IN (
    'helpful',
    'misleading',
    'incomplete',
    'needs_context'
  )),

  -- Optional details
  detail TEXT,

  -- Metadata
  review_duration_ms INTEGER CHECK (review_duration_ms >= 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for clinical_insights_feedback
CREATE INDEX idx_feedback_insight_id ON clinical_insights_feedback(insight_id);
CREATE INDEX idx_feedback_reviewer_id ON clinical_insights_feedback(reviewer_person_id);
CREATE INDEX idx_feedback_organization_id ON clinical_insights_feedback(organization_id);
CREATE INDEX idx_feedback_action ON clinical_insights_feedback(action);
CREATE INDEX idx_feedback_created_at ON clinical_insights_feedback(created_at DESC);

-- ============================================================================
-- RLS Policies
-- ============================================================================

-- Enable RLS
ALTER TABLE clinical_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_insights_feedback ENABLE ROW LEVEL SECURITY;

-- clinical_insights: Read policy (provider or admin of org)
CREATE POLICY "read_clinical_insights_org_member" ON clinical_insights
  FOR SELECT
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM organization_members
      WHERE person_id = auth.uid()
        AND organization_id = clinical_insights.organization_id
    )
  );

-- clinical_insights: Read policy (platform admin)
CREATE POLICY "read_clinical_insights_platform_admin" ON clinical_insights
  FOR SELECT
  TO authenticated
  USING (
    (SELECT COUNT(*) FROM organization_members
     WHERE person_id = auth.uid()
       AND role IN ('platform_admin')) > 0
  );

-- clinical_insights: Insert policy (system/backend only, via RLS service role bypass)
-- No RLS policy needed — inserted by backend with service role client

-- clinical_insights_feedback: Read policy (creator or org admin)
CREATE POLICY "read_feedback_creator_or_admin" ON clinical_insights_feedback
  FOR SELECT
  TO authenticated
  USING (
    reviewer_person_id = auth.uid()
    OR organization_id IN (
      SELECT organization_id
      FROM organization_members
      WHERE person_id = auth.uid()
        AND role IN ('owner', 'admin')
    )
  );

-- clinical_insights_feedback: Insert policy (any org member can submit feedback)
CREATE POLICY "insert_feedback_org_member" ON clinical_insights_feedback
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IN (
      SELECT organization_id
      FROM organization_members
      WHERE person_id = auth.uid()
        AND organization_id = clinical_insights_feedback.organization_id
    )
    AND reviewer_person_id = auth.uid()
  );

-- ============================================================================
-- Comment
-- ============================================================================
COMMENT ON TABLE clinical_insights IS 'Phase 3: Immutable audit log of AI-generated clinical insights with explanations and confidence scores';
COMMENT ON TABLE clinical_insights_feedback IS 'Phase 3: Immutable learning log of provider feedback on insights for RLHF training';
;
