
-- 1. prompt_templates — 프롬프트 버전 관리
CREATE TABLE IF NOT EXISTS prompt_templates (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  version       integer NOT NULL DEFAULT 1,
  prompt_text   text NOT NULL,
  model         text NOT NULL DEFAULT 'gemini-2.5-flash',
  config        jsonb NOT NULL DEFAULT '{}',
  is_active     boolean NOT NULL DEFAULT false,
  created_by    uuid REFERENCES persons(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_prompt_templates_name_version UNIQUE (name, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_prompt_templates_active
  ON prompt_templates (name) WHERE is_active = true;

COMMENT ON TABLE prompt_templates IS 'Versioned LLM prompt templates — tracks changes for A/B testing and audit';

ALTER TABLE prompt_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "platform_admin_full_access" ON prompt_templates
  FOR ALL USING (is_platform_admin());

CREATE POLICY "org_admin_read" ON prompt_templates
  FOR SELECT USING (true);

-- 2. prompt_evolution_rules — evolved instructions (was in-memory)
CREATE TABLE IF NOT EXISTS prompt_evolution_rules (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id   uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  instruction       text NOT NULL,
  source_rule_ids   text[] NOT NULL DEFAULT '{}',
  strength          text NOT NULL CHECK (strength IN ('hard', 'soft')),
  evidence_count    integer NOT NULL DEFAULT 0,
  is_active         boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prompt_evolution_rules_org_active
  ON prompt_evolution_rules (organization_id) WHERE is_active = true;

COMMENT ON TABLE prompt_evolution_rules IS 'Persisted evolved instructions from EvoClinician feedback loop — replaces in-memory Map';

ALTER TABLE prompt_evolution_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org_member_read" ON prompt_evolution_rules
  FOR SELECT USING (is_org_member(organization_id));

CREATE POLICY "platform_admin_all" ON prompt_evolution_rules
  FOR ALL USING (is_platform_admin());

-- 3. Add prompt_version to ai_inference_log for traceability
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'ai_inference_log' AND column_name = 'prompt_version'
  ) THEN
    ALTER TABLE ai_inference_log ADD COLUMN prompt_version text;
    COMMENT ON COLUMN ai_inference_log.prompt_version IS 'prompt_templates.name:version used for this inference';
  END IF;
END $$;
;
