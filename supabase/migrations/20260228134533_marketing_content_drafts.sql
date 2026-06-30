CREATE TABLE IF NOT EXISTS public.marketing_content_drafts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  client_person_id UUID NOT NULL REFERENCES public.persons(id) ON DELETE CASCADE,
  provider_person_id UUID NOT NULL REFERENCES public.persons(id),
  content_type TEXT NOT NULL CHECK (content_type IN ('blog', 'instagram', 'kakao')),
  title TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  hashtags TEXT[] DEFAULT '{}',
  source_report_snapshot JSONB NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'editing', 'approved', 'rejected')),
  rejection_reason TEXT,
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES public.persons(id),
  filter_warnings TEXT[] DEFAULT '{}',
  generation_model TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mcd_org ON public.marketing_content_drafts(organization_id);
CREATE INDEX IF NOT EXISTS idx_mcd_client ON public.marketing_content_drafts(client_person_id);
CREATE INDEX IF NOT EXISTS idx_mcd_status ON public.marketing_content_drafts(status);
CREATE INDEX IF NOT EXISTS idx_mcd_created ON public.marketing_content_drafts(created_at DESC);

ALTER TABLE public.marketing_content_drafts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org_members_read_content_drafts"
  ON public.marketing_content_drafts FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "org_provider_insert_content_drafts"
  ON public.marketing_content_drafts FOR INSERT
  WITH CHECK (is_org_member(organization_id));

CREATE POLICY "org_provider_update_content_drafts"
  ON public.marketing_content_drafts FOR UPDATE
  USING (is_org_member(organization_id));

CREATE POLICY "org_admin_delete_content_drafts"
  ON public.marketing_content_drafts FOR DELETE
  USING (is_org_admin(organization_id));

CREATE OR REPLACE FUNCTION public.set_mcd_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_mcd_updated_at ON public.marketing_content_drafts;
CREATE TRIGGER trg_mcd_updated_at
  BEFORE UPDATE ON public.marketing_content_drafts
  FOR EACH ROW EXECUTE FUNCTION public.set_mcd_updated_at();;
