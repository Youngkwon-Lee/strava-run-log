
CREATE TABLE IF NOT EXISTS patient_education_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  person_id UUID NOT NULL REFERENCES persons(id),
  content_id UUID NOT NULL REFERENCES clinical_content_registry(id),
  encounter_id UUID REFERENCES encounters(id),
  delivered_by_person_id UUID REFERENCES persons(id),
  delivery_method TEXT CHECK (delivery_method IN ('in_app','email','sms','paper')) DEFAULT 'in_app',
  language TEXT DEFAULT 'ko',
  viewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE patient_education_deliveries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org_member_read" ON patient_education_deliveries
  FOR SELECT TO authenticated
  USING (is_org_member(organization_id));

CREATE POLICY "org_member_insert" ON patient_education_deliveries
  FOR INSERT TO authenticated
  WITH CHECK (is_org_member(organization_id));

CREATE INDEX idx_ped_org_person ON patient_education_deliveries (organization_id, person_id);
CREATE INDEX idx_ped_content ON patient_education_deliveries (content_id);
;
