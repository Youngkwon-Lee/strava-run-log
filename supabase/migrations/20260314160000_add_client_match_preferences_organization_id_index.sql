-- P1 follow-up: add covering index for client_match_preferences foreign key.

create index if not exists idx_client_match_preferences_organization_id
  on public.client_match_preferences (organization_id);
