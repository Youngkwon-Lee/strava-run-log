
CREATE TABLE IF NOT EXISTS benchmark_results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  wod_code VARCHAR(50) NOT NULL,
  result_value FLOAT NOT NULL,
  result_type VARCHAR(20) NOT NULL CHECK (result_type IN ('time', 'reps', 'rounds_plus_reps')),
  scaling VARCHAR(20) NOT NULL DEFAULT 'rx' CHECK (scaling IN ('rx', 'scaled', 'foundations')),
  notes TEXT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_benchmark_results_person ON benchmark_results(person_id, wod_code);
CREATE INDEX IF NOT EXISTS idx_benchmark_results_org ON benchmark_results(organization_id);
CREATE INDEX IF NOT EXISTS idx_benchmark_results_wod_recorded ON benchmark_results(wod_code, recorded_at DESC);

ALTER TABLE benchmark_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members can view benchmark_results"
  ON benchmark_results FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "org members can insert benchmark_results"
  ON benchmark_results FOR INSERT
  WITH CHECK (is_org_member(organization_id));

CREATE POLICY "org admins can delete benchmark_results"
  ON benchmark_results FOR DELETE
  USING (is_org_admin(organization_id));
;
