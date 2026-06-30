-- Wave D3: remove exact overlap policies (very low risk).
-- Scope: pghd_connections, terminology_registry

-- pghd_connections:
-- keep "pghd_connections_user_access" (ALL) and remove action-specific duplicates.
drop policy if exists "pghd_connections_insert" on public.pghd_connections;
drop policy if exists "pghd_connections_select" on public.pghd_connections;
drop policy if exists "pghd_connections_update" on public.pghd_connections;
drop policy if exists "pghd_connections_delete" on public.pghd_connections;
-- terminology_registry:
-- keep service-role ALL policy and remove redundant UPDATE policy.
drop policy if exists "terminology_registry_update_service" on public.terminology_registry;
