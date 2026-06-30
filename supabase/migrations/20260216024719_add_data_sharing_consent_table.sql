CREATE TABLE data_sharing_consent (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_person_id uuid NOT NULL REFERENCES persons(id),
  from_org_id uuid NOT NULL REFERENCES organizations(id),
  to_org_id uuid NOT NULL REFERENCES organizations(id),
  scope text[] NOT NULL DEFAULT ARRAY['summary_only']::text[],
  consent_type text NOT NULL DEFAULT 'explicit',
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  revoked_at timestamptz,
  revoked_by uuid REFERENCES persons(id),
  revocation_reason text,
  granted_by uuid NOT NULL REFERENCES persons(id),
  notes text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(subject_person_id, from_org_id, to_org_id)
);

ALTER TABLE data_sharing_consent ADD CONSTRAINT data_sharing_consent_type_check
  CHECK (consent_type IN ('explicit','implicit','emergency','legal'));
ALTER TABLE data_sharing_consent ADD CONSTRAINT data_sharing_consent_not_same_org
  CHECK (from_org_id != to_org_id);

CREATE INDEX idx_data_sharing_subject ON data_sharing_consent(subject_person_id);
CREATE INDEX idx_data_sharing_from_org ON data_sharing_consent(from_org_id);
CREATE INDEX idx_data_sharing_to_org ON data_sharing_consent(to_org_id);
CREATE INDEX idx_data_sharing_active ON data_sharing_consent(subject_person_id)
  WHERE revoked_at IS NULL;

ALTER TABLE data_sharing_consent ENABLE ROW LEVEL SECURITY;

CREATE POLICY sharing_self_read ON data_sharing_consent FOR SELECT
  USING (subject_person_id = get_my_person_id());
CREATE POLICY sharing_from_org_read ON data_sharing_consent FOR SELECT
  USING (is_org_admin(from_org_id));
CREATE POLICY sharing_to_org_read ON data_sharing_consent FOR SELECT
  USING (is_org_admin(to_org_id));
CREATE POLICY sharing_self_manage ON data_sharing_consent FOR ALL
  USING (subject_person_id = get_my_person_id());
CREATE POLICY sharing_admin_manage ON data_sharing_consent FOR ALL
  USING (is_org_admin(from_org_id));
CREATE POLICY sharing_service ON data_sharing_consent FOR ALL TO service_role USING (true);

COMMENT ON TABLE data_sharing_consent IS 'Cross-org data sharing consent. scope: observations, notes, media, encounters, summary_only.';;
