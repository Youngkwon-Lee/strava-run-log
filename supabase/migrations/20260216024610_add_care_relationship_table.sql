-- care_relationship: 담당 provider↔client 배정
CREATE TABLE care_relationship (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id),
  client_person_id uuid NOT NULL REFERENCES persons(id),
  provider_person_id uuid NOT NULL REFERENCES persons(id),
  role text NOT NULL DEFAULT 'primary',
  status text NOT NULL DEFAULT 'active',
  start_at timestamptz NOT NULL DEFAULT now(),
  end_at timestamptz,
  notes text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, client_person_id, provider_person_id)
);

ALTER TABLE care_relationship ADD CONSTRAINT care_relationship_role_check
  CHECK (role IN ('primary','secondary','supervisor','consultant'));
ALTER TABLE care_relationship ADD CONSTRAINT care_relationship_status_check
  CHECK (status IN ('active','paused','closed','transferred'));
ALTER TABLE care_relationship ADD CONSTRAINT care_relationship_not_self
  CHECK (client_person_id != provider_person_id);

CREATE INDEX idx_care_relationship_org ON care_relationship(organization_id);
CREATE INDEX idx_care_relationship_client ON care_relationship(client_person_id);
CREATE INDEX idx_care_relationship_provider ON care_relationship(provider_person_id);
CREATE INDEX idx_care_relationship_active ON care_relationship(organization_id, status) WHERE status = 'active';

ALTER TABLE care_relationship ENABLE ROW LEVEL SECURITY;

CREATE POLICY care_rel_self_read ON care_relationship FOR SELECT
  USING (client_person_id = get_my_person_id() OR provider_person_id = get_my_person_id());
CREATE POLICY care_rel_org_read ON care_relationship FOR SELECT
  USING (is_org_member(organization_id));
CREATE POLICY care_rel_admin_write ON care_relationship FOR ALL
  USING (is_org_admin(organization_id));
CREATE POLICY care_rel_provider_write ON care_relationship FOR INSERT
  WITH CHECK (provider_person_id = get_my_person_id() AND is_org_member(organization_id));
CREATE POLICY care_rel_service ON care_relationship FOR ALL TO service_role USING (true);

COMMENT ON TABLE care_relationship IS 'Provider-client care assignment within an org. Tracks primary/secondary provider, active/closed status.';;
