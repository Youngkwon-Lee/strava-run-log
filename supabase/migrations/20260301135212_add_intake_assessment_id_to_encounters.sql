
ALTER TABLE encounters
  ADD COLUMN IF NOT EXISTS intake_assessment_id uuid
    REFERENCES assessment_form_responses(id) ON DELETE SET NULL;

COMMENT ON COLUMN encounters.intake_assessment_id IS
  'Encounter 생성 시점 기준 14일 이내 최근 self-assessment 스냅샷 참조. 한 번 연결되면 재연결 금지.';

CREATE INDEX IF NOT EXISTS idx_encounters_intake_assessment_id
  ON encounters(intake_assessment_id)
  WHERE intake_assessment_id IS NOT NULL;
;
