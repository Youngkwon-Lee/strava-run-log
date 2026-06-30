
-- Create the missing organization_subscriptions table
-- Referenced by triggers: trg_auto_create_org_subscription, trg_auto_create_subscription
CREATE TABLE IF NOT EXISTS public.organization_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES public.platform_plans(id),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'trialing', 'past_due', 'canceled', 'paused')),
  billing_cycle text DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly')),
  current_period_start timestamptz DEFAULT now(),
  current_period_end timestamptz,
  trial_start timestamptz,
  trial_end timestamptz,
  usage_data jsonb DEFAULT '{}'::jsonb,
  canceled_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id)
);

-- RLS
ALTER TABLE public.organization_subscriptions ENABLE ROW LEVEL SECURITY;

-- Policy: org members can read their own subscription
CREATE POLICY "org_members_can_read_subscription"
  ON public.organization_subscriptions
  FOR SELECT
  USING (is_org_member(organization_id));

-- Policy: org admins can update subscription
CREATE POLICY "org_admins_can_update_subscription"
  ON public.organization_subscriptions
  FOR UPDATE
  USING (is_org_admin(organization_id));

-- Index
CREATE INDEX idx_org_subscriptions_org_id ON public.organization_subscriptions(organization_id);
CREATE INDEX idx_org_subscriptions_status ON public.organization_subscriptions(status);

-- updated_at trigger
CREATE TRIGGER trigger_org_subscriptions_updated_at
  BEFORE UPDATE ON public.organization_subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
;
