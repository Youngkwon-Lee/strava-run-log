-- Phase 4: Billing consolidation (18 -> 11)

-- DROP redundant subscription tables
DROP TABLE IF EXISTS customer_subscriptions CASCADE;
DROP TABLE IF EXISTS member_subscriptions CASCADE;
DROP TABLE IF EXISTS organization_subscriptions CASCADE;
DROP TABLE IF EXISTS membership_plans CASCADE;
DROP TABLE IF EXISTS subscription_payments CASCADE;
DROP TABLE IF EXISTS billing_keys CASCADE;
DROP TABLE IF EXISTS payment_events CASCADE;
DROP TABLE IF EXISTS payment_history CASCADE;

-- CREATE unified subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id),
  person_id uuid REFERENCES persons(id),
  plan_id uuid NOT NULL REFERENCES subscription_plans(id),
  status text NOT NULL DEFAULT 'active',
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean DEFAULT false,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS for subscriptions
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'org_member_access' AND tablename = 'subscriptions') THEN
    EXECUTE 'CREATE POLICY org_member_access ON subscriptions FOR ALL USING (is_org_member(organization_id))';
  END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_org ON subscriptions(organization_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_person ON subscriptions(person_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);;
