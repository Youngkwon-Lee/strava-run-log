
-- Discharge Outcome Recording — Data Flywheel Phase 3
-- Stores predicted vs actual outcomes at discharge for continuous AI improvement

CREATE TABLE IF NOT EXISTS public.discharge_outcome_recordings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- References
  episode_id uuid NOT NULL REFERENCES public.episodes(id) ON DELETE CASCADE,
  encounter_id uuid NOT NULL REFERENCES public.encounters(id) ON DELETE CASCADE,
  subject_person_id uuid NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  
  -- Predicted profile (at discharge decision point)
  -- ClientOutcomeProfile JSON: { clientPersonId, persona, riskLevel, predictions[], successProbability, recommendation }
  predicted_profile jsonb NOT NULL,
  
  -- Actual outcomes (from final assessments)
  -- Array<{ toolCode, baseline, finalValue, mcidAchieved, weeksToDischarge }>
  actual_outcomes jsonb NOT NULL,
  
  -- Comparison metrics
  accuracy_score numeric(5,2) NOT NULL, -- 0-100: how well prediction matched actual
  prediction_error numeric(5,2), -- avg absolute error (weeks)
  lessons text[], -- ["AT recovers 20% faster", "High-risk need +2 weeks"]
  
  -- Audit
  created_by uuid NOT NULL REFERENCES public.persons(id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  -- Validation
  CONSTRAINT chk_accuracy_score CHECK (accuracy_score >= 0 AND accuracy_score <= 100)
);

-- Enable RLS
ALTER TABLE public.discharge_outcome_recordings ENABLE ROW LEVEL SECURITY;

-- RLS: Users can read discharge outcomes for their organization
CREATE POLICY discharge_outcome_read ON public.discharge_outcome_recordings
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.organization_members om
      WHERE om.organization_id = discharge_outcome_recordings.organization_id
      AND om.person_id = auth.uid()
    )
  );

-- RLS: Only providers can create discharge outcomes
CREATE POLICY discharge_outcome_create ON public.discharge_outcome_recordings
  FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.organization_members om
      WHERE om.organization_id = discharge_outcome_recordings.organization_id
      AND om.person_id = auth.uid()
      AND om.role IN ('owner', 'admin', 'provider')
    )
  );

-- Audit indexes
CREATE INDEX idx_discharge_outcome_episode ON public.discharge_outcome_recordings(episode_id);
CREATE INDEX idx_discharge_outcome_subject ON public.discharge_outcome_recordings(subject_person_id);
CREATE INDEX idx_discharge_outcome_org ON public.discharge_outcome_recordings(organization_id);
CREATE INDEX idx_discharge_outcome_created ON public.discharge_outcome_recordings(created_at DESC);

COMMENT ON TABLE public.discharge_outcome_recordings IS
  'Data Flywheel Phase 3: Records predicted vs actual outcomes at discharge.
   Used for continuous AI model improvement through RLHF.
   - predicted_profile: ClientOutcomeProfile (from OutcomePredictionService)
   - actual_outcomes: Final assessment values at discharge
   - accuracy_score: How well prediction matched reality (0-100)
   - lessons: Extracted insights for persona-specific recovery model tuning';
;
