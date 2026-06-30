-- P1 follow-up: add covering indexes for client_session_packages foreign keys.

create index if not exists idx_client_session_packages_invoice_id
  on public.client_session_packages (invoice_id);
create index if not exists idx_client_session_packages_organization_id
  on public.client_session_packages (organization_id);
create index if not exists idx_client_session_packages_package_id
  on public.client_session_packages (package_id);
