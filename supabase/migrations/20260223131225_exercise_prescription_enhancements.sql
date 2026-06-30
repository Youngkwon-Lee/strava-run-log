
-- ============================================================
-- Exercise Prescription: add missing clinical fields
-- ============================================================
ALTER TABLE exercise_prescriptions
  ADD COLUMN IF NOT EXISTS hold_seconds        INTEGER,
  ADD COLUMN IF NOT EXISTS frequency_per_week  INTEGER,
  ADD COLUMN IF NOT EXISTS duration_weeks      INTEGER,
  ADD COLUMN IF NOT EXISTS status              TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS phase               TEXT,
  ADD COLUMN IF NOT EXISTS rpe_target          SMALLINT,
  ADD COLUMN IF NOT EXISTS episode_id          UUID REFERENCES episodes(id) ON DELETE SET NULL;

ALTER TABLE exercise_prescriptions
  ADD CONSTRAINT chk_exercise_prescriptions_phase
    CHECK (phase IS NULL OR phase IN ('acute','subacute','chronic','maintenance','prevention')),
  ADD CONSTRAINT chk_exercise_prescriptions_rpe
    CHECK (rpe_target IS NULL OR (rpe_target >= 6 AND rpe_target <= 20)),
  ADD CONSTRAINT chk_exercise_prescriptions_status
    CHECK (status IN ('active','paused','completed','discontinued'));

CREATE INDEX IF NOT EXISTS idx_exercise_prescriptions_episode
  ON exercise_prescriptions(episode_id) WHERE episode_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_exercise_prescriptions_status
  ON exercise_prescriptions(status);

-- ============================================================
-- Exercise Programs: add episode / care_plan / phase linkage
-- ============================================================
ALTER TABLE exercise_programs
  ADD COLUMN IF NOT EXISTS episode_id      UUID REFERENCES episodes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS care_plan_id    UUID REFERENCES care_plans(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS current_phase   TEXT NOT NULL DEFAULT 'acute',
  ADD COLUMN IF NOT EXISTS phase_history   JSONB NOT NULL DEFAULT '[]';

ALTER TABLE exercise_programs
  ADD CONSTRAINT chk_exercise_programs_phase
    CHECK (current_phase IN ('acute','subacute','chronic','maintenance','prevention')),
  ADD CONSTRAINT chk_exercise_programs_status
    CHECK (status IN ('active','paused','completed','discontinued'));

CREATE INDEX IF NOT EXISTS idx_exercise_programs_episode
  ON exercise_programs(episode_id) WHERE episode_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_exercise_programs_care_plan
  ON exercise_programs(care_plan_id) WHERE care_plan_id IS NOT NULL;
;
