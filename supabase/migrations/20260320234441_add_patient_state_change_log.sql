-- ============================================================
-- Patient State Change Log
-- Date: 2026-03-21
-- Purpose: persist before/after patient_state diffs for audit/debug
-- ============================================================

CREATE TABLE IF NOT EXISTS public.patient_state_change_log (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_state_id    UUID NULL REFERENCES public.patient_clinical_state(id) ON DELETE SET NULL,
  subject_person_id   UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  organization_id     UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  trigger_event       TEXT NULL,
  trigger_encounter_id UUID NULL REFERENCES public.encounters(id) ON DELETE SET NULL,
  state_version       INTEGER NOT NULL DEFAULT 1,
  computed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  before_state        JSONB NULL,
  after_state         JSONB NOT NULL,
  diff_summary        JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_patient_state_change_log_subject_org_created
  ON public.patient_state_change_log(subject_person_id, organization_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_patient_state_change_log_patient_state
  ON public.patient_state_change_log(patient_state_id, created_at DESC);

ALTER TABLE public.patient_state_change_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY patient_state_change_log_select ON public.patient_state_change_log
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = get_my_person_id()
        AND om.organization_id = patient_state_change_log.organization_id
        AND om.role = ANY(ARRAY['owner','admin','provider','staff'])
        AND om.status = 'active'
    )
  );

CREATE POLICY patient_state_change_log_insert ON public.patient_state_change_log
  FOR INSERT WITH CHECK (false);;
