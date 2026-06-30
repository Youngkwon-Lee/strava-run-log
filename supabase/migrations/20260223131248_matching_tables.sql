
-- ============================================================
-- Matching: provider preferences
-- ============================================================
CREATE TABLE IF NOT EXISTS provider_match_preferences (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_person_id      UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  max_active_clients      INTEGER NOT NULL DEFAULT 20,
  accepts_new_clients     BOOLEAN NOT NULL DEFAULT true,
  telehealth_available    BOOLEAN NOT NULL DEFAULT false,
  accepted_condition_tags TEXT[]  NOT NULL DEFAULT '{}',
  accepted_client_kinds   TEXT[]  NOT NULL DEFAULT '{}',
  session_rate_min        INTEGER,
  session_rate_max        INTEGER,
  preferred_client_age_min INTEGER,
  preferred_client_age_max INTEGER,
  provider_gender         TEXT,
  languages_spoken        TEXT[]  NOT NULL DEFAULT '{ko}',
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(provider_person_id, organization_id)
);
CREATE INDEX IF NOT EXISTS idx_pmp_provider ON provider_match_preferences(provider_person_id);
CREATE INDEX IF NOT EXISTS idx_pmp_org      ON provider_match_preferences(organization_id);

ALTER TABLE provider_match_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "org members can read provider match prefs"
  ON provider_match_preferences FOR SELECT
  USING (is_org_member(organization_id));
CREATE POLICY "provider can manage own prefs"
  ON provider_match_preferences FOR ALL
  USING (provider_person_id = get_my_person_id());

-- ============================================================
-- Matching: client preferences
-- ============================================================
CREATE TABLE IF NOT EXISTS client_match_preferences (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_person_id          UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  organization_id           UUID REFERENCES organizations(id) ON DELETE SET NULL,
  preferred_service_domain  TEXT,
  preferred_expert_types    TEXT[]  NOT NULL DEFAULT '{}',
  preferred_specialties     TEXT[]  NOT NULL DEFAULT '{}',
  location_lat              FLOAT,
  location_lng              FLOAT,
  location_label            TEXT,
  max_distance_km           FLOAT   NOT NULL DEFAULT 10.0,
  telehealth_ok             BOOLEAN NOT NULL DEFAULT false,
  preferred_provider_gender TEXT,
  preferred_languages       TEXT[]  NOT NULL DEFAULT '{ko}',
  preferred_days            TEXT[]  NOT NULL DEFAULT '{}',
  preferred_time_slots      JSONB   NOT NULL DEFAULT '[]',
  budget_max_per_session    INTEGER,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(client_person_id)
);
CREATE INDEX IF NOT EXISTS idx_cmp_client ON client_match_preferences(client_person_id);

ALTER TABLE client_match_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "client can manage own match prefs"
  ON client_match_preferences FOR ALL
  USING (client_person_id = get_my_person_id());
CREATE POLICY "org members can read client match prefs"
  ON client_match_preferences FOR SELECT
  USING (organization_id IS NULL OR is_org_member(organization_id));

-- ============================================================
-- Matching: results & feedback loop
-- ============================================================
CREATE TABLE IF NOT EXISTS match_results (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_person_id    UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  provider_person_id  UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  organization_id     UUID REFERENCES organizations(id) ON DELETE SET NULL,
  lead_id             UUID REFERENCES leads(id) ON DELETE SET NULL,
  -- Scores
  total_score         FLOAT NOT NULL,
  specialty_score     FLOAT,
  availability_score  FLOAT,
  location_score      FLOAT,
  load_score          FLOAT,
  quality_score       FLOAT,
  preference_score    FLOAT,
  boost_score         FLOAT,
  -- Explainability
  match_reasons       JSONB NOT NULL DEFAULT '[]',
  -- Status & feedback
  status              TEXT NOT NULL DEFAULT 'pending',
  outcome_rating      SMALLINT,
  was_successful      BOOLEAN,
  algorithm_version   TEXT NOT NULL DEFAULT 'v1',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_match_results_status
    CHECK (status IN ('pending','accepted','rejected','expired')),
  CONSTRAINT chk_match_results_rating
    CHECK (outcome_rating IS NULL OR (outcome_rating >= 1 AND outcome_rating <= 5))
);
CREATE INDEX IF NOT EXISTS idx_mr_client   ON match_results(client_person_id);
CREATE INDEX IF NOT EXISTS idx_mr_provider ON match_results(provider_person_id);
CREATE INDEX IF NOT EXISTS idx_mr_status   ON match_results(status);
CREATE INDEX IF NOT EXISTS idx_mr_lead     ON match_results(lead_id) WHERE lead_id IS NOT NULL;

ALTER TABLE match_results ENABLE ROW LEVEL SECURITY;
CREATE POLICY "client can view own match results"
  ON match_results FOR SELECT
  USING (client_person_id = get_my_person_id());
CREATE POLICY "provider can view own match results"
  ON match_results FOR SELECT
  USING (provider_person_id = get_my_person_id());
CREATE POLICY "org admin can manage match results"
  ON match_results FOR ALL
  USING (organization_id IS NOT NULL AND is_org_admin(organization_id));

-- ============================================================
-- terminology_registry: add OMOP columns
-- ============================================================
ALTER TABLE terminology_registry
  ADD COLUMN IF NOT EXISTS omop_concept_id    INTEGER,
  ADD COLUMN IF NOT EXISTS omop_domain_id     TEXT,
  ADD COLUMN IF NOT EXISTS omop_standard_concept TEXT;

CREATE INDEX IF NOT EXISTS idx_terminology_omop
  ON terminology_registry(omop_concept_id) WHERE omop_concept_id IS NOT NULL;
;
