-- P1 follow-up: add covering index for provider_referral_links foreign key.

create index if not exists idx_provider_referral_links_organization_id
  on public.provider_referral_links (organization_id);
