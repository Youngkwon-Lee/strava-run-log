-- P1 follow-up: add covering index for match_results foreign key.

create index if not exists idx_match_results_organization_id
  on public.match_results (organization_id);
