-- Add intervention-specific fields to procedures (GPT Block 5 gap fix)

-- 0. Ensure approach_key has UNIQUE constraint for FK reference
ALTER TABLE treatment_approaches ADD CONSTRAINT treatment_approaches_approach_key_unique UNIQUE (approach_key);

-- 1. intensity: RPE, %1RM, resistance level, etc.
ALTER TABLE procedures ADD COLUMN IF NOT EXISTS intensity jsonb;
COMMENT ON COLUMN procedures.intensity IS 'Structured intensity data: {type: "RPE"|"percent_1rm"|"resistance"|"custom", value: number, unit?: string}';

-- 2. approach_key: links to treatment_approaches catalog
ALTER TABLE procedures ADD COLUMN IF NOT EXISTS approach_key text REFERENCES treatment_approaches(approach_key);
COMMENT ON COLUMN procedures.approach_key IS 'Treatment approach used (MDT, Bobath, Schroth, etc.) — FK to treatment_approaches.approach_key';

-- 3. mode: passive/active/assisted/education
ALTER TABLE procedures ADD COLUMN IF NOT EXISTS mode text;
COMMENT ON COLUMN procedures.mode IS 'Intervention delivery mode: passive, active, assisted, resistive, education, observation';
ALTER TABLE procedures ADD CONSTRAINT procedures_mode_check CHECK (mode IS NULL OR mode IN ('passive', 'active', 'assisted', 'resistive', 'education', 'observation'));

-- 4. Index on approach_key for join performance
CREATE INDEX IF NOT EXISTS idx_procedures_approach_key ON procedures(approach_key) WHERE approach_key IS NOT NULL;

-- 5. Index on mode for filtering
CREATE INDEX IF NOT EXISTS idx_procedures_mode ON procedures(mode) WHERE mode IS NOT NULL;;
