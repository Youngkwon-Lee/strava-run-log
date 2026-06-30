alter table public.movement_pattern_impairment_links enable row level security;
alter table public.impairment_assessment_links enable row level security;
alter table public.impairment_observation_links enable row level security;

create policy movement_pattern_impairment_links_read_all
on public.movement_pattern_impairment_links
for select
to authenticated
using (true);

create policy impairment_assessment_links_read_all
on public.impairment_assessment_links
for select
to authenticated
using (true);

create policy impairment_observation_links_read_all
on public.impairment_observation_links
for select
to authenticated
using (true);

create policy client_portal_invites_org_member_read
on public.client_portal_invites
for select
to authenticated
using (is_org_member(organization_id));

create policy client_portal_invites_org_member_insert
on public.client_portal_invites
for insert
to authenticated
with check (
  is_org_member(organization_id)
  and created_by = get_my_person_id()
);

create policy client_portal_invites_org_member_update
on public.client_portal_invites
for update
to authenticated
using (is_org_member(organization_id))
with check (is_org_member(organization_id));

alter function public.match_client_media_summaries(
  extensions.vector,
  double precision,
  integer,
  uuid,
  uuid,
  uuid,
  text
) set search_path = public, extensions;

alter function public.match_client_memory_chunks(
  extensions.vector,
  double precision,
  integer,
  uuid,
  uuid,
  uuid,
  text,
  text[]
) set search_path = public, extensions;

create index if not exists idx_client_media_summaries_author_person_id
  on public.client_media_summaries (author_person_id);

create index if not exists idx_client_media_summaries_encounter_id
  on public.client_media_summaries (encounter_id);

create index if not exists idx_client_memory_chunks_author_person_id
  on public.client_memory_chunks (author_person_id);

create index if not exists idx_client_memory_chunks_encounter_id
  on public.client_memory_chunks (encounter_id);

create index if not exists idx_client_portal_invites_created_by
  on public.client_portal_invites (created_by);

create index if not exists idx_client_portal_invites_person_id
  on public.client_portal_invites (person_id);;
