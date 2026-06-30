-- rate_plan: 서비스 단가 테이블
CREATE TABLE rate_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id),
  name text NOT NULL,
  service_type text NOT NULL,
  unit_price numeric NOT NULL,
  currency text NOT NULL DEFAULT 'KRW',
  unit text NOT NULL DEFAULT 'session',
  default_duration_minutes integer DEFAULT 30,
  is_active boolean DEFAULT true,
  valid_from date,
  valid_to date,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE rate_plans ADD CONSTRAINT rate_plans_unit_check
  CHECK (unit IN ('session','minute','hour','package','subscription','custom'));
ALTER TABLE rate_plans ADD CONSTRAINT rate_plans_price_positive
  CHECK (unit_price >= 0);

CREATE INDEX idx_rate_plans_org ON rate_plans(organization_id);
CREATE INDEX idx_rate_plans_active ON rate_plans(organization_id, is_active) WHERE is_active = true;

ALTER TABLE rate_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY rate_plans_org_read ON rate_plans FOR SELECT
  USING (is_org_member(organization_id));
CREATE POLICY rate_plans_admin_write ON rate_plans FOR ALL
  USING (is_org_admin(organization_id));
CREATE POLICY rate_plans_service ON rate_plans FOR ALL TO service_role USING (true);

COMMENT ON TABLE rate_plans IS 'Service pricing per org. unit: session, minute, hour, package, subscription.';

-- encounters에 rate_plan_id FK 추가
ALTER TABLE encounters ADD COLUMN rate_plan_id uuid REFERENCES rate_plans(id);
COMMENT ON COLUMN encounters.rate_plan_id IS 'Optional rate plan applied to this encounter for billing.';;
