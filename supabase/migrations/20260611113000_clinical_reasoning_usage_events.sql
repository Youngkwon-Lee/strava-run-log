create table if not exists public.clinical_reasoning_usage_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  encounter_id uuid references public.encounters(id) on delete set null,
  actor_person_id uuid not null references public.persons(id) on delete cascade,
  event_name text not null default 'clinical_reasoning_quick_observation',
  action text not null,
  surface text not null,
  reasoning_layer text not null,
  recommended_regions text[] not null default array[]::text[],
  recommended_region_count integer not null default 0,
  show_all boolean not null default false,
  visible_anchor_count integer,
  total_anchor_count integer,
  observation_code text,
  observation_category text,
  observation_regions text[] not null default array[]::text[],
  is_recommended_anchor boolean,
  laterality text,
  severity text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint clinical_reasoning_usage_event_name_check check (
    event_name = 'clinical_reasoning_quick_observation'
  ),
  constraint clinical_reasoning_usage_action_check check (
    action = any (array[
      'view',
      'toggle_show_all',
      'toggle_recommended',
      'save_success',
      'save_error'
    ])
  ),
  constraint clinical_reasoning_usage_laterality_check check (
    laterality is null or laterality = any (array['left', 'right', 'bilateral'])
  ),
  constraint clinical_reasoning_usage_severity_check check (
    severity is null or severity = any (array['mild', 'moderate', 'severe'])
  ),
  constraint clinical_reasoning_usage_anchor_count_check check (
    visible_anchor_count is null or visible_anchor_count >= 0
  ),
  constraint clinical_reasoning_usage_total_count_check check (
    total_anchor_count is null or total_anchor_count >= 0
  )
);
comment on table public.clinical_reasoning_usage_events is
  'Privacy-safe product usage events for the clinical reasoning layer. Do not store patient text, names, or raw clinical narratives.';
comment on column public.clinical_reasoning_usage_events.metadata is
  'Reserved for non-PHI product diagnostics only.';
create index if not exists idx_clinical_reasoning_usage_org_created
  on public.clinical_reasoning_usage_events (organization_id, created_at desc);
create index if not exists idx_clinical_reasoning_usage_encounter
  on public.clinical_reasoning_usage_events (encounter_id, created_at desc)
  where encounter_id is not null;
create index if not exists idx_clinical_reasoning_usage_action
  on public.clinical_reasoning_usage_events (organization_id, event_name, action, created_at desc);
create index if not exists idx_clinical_reasoning_usage_observation_code
  on public.clinical_reasoning_usage_events (organization_id, observation_code, created_at desc)
  where observation_code is not null;
alter table public.clinical_reasoning_usage_events enable row level security;
drop policy if exists clinical_reasoning_usage_events_org_select
  on public.clinical_reasoning_usage_events;
create policy clinical_reasoning_usage_events_org_select
  on public.clinical_reasoning_usage_events
  for select
  using (
    exists (
      select 1
      from public.organization_members om
      join public.persons p on p.id = om.person_id
      where om.organization_id = clinical_reasoning_usage_events.organization_id
        and p.auth_user_id = auth.uid()
    )
  );
drop policy if exists clinical_reasoning_usage_events_org_insert
  on public.clinical_reasoning_usage_events;
create policy clinical_reasoning_usage_events_org_insert
  on public.clinical_reasoning_usage_events
  for insert
  with check (
    actor_person_id = (
      select p.id
      from public.persons p
      where p.auth_user_id = auth.uid()
      limit 1
    )
    and exists (
      select 1
      from public.organization_members om
      where om.organization_id = clinical_reasoning_usage_events.organization_id
        and om.person_id = clinical_reasoning_usage_events.actor_person_id
    )
    and (
      encounter_id is null
      or exists (
        select 1
        from public.encounters e
        where e.id = clinical_reasoning_usage_events.encounter_id
          and e.organization_id = clinical_reasoning_usage_events.organization_id
          and e.deleted_at is null
      )
    )
  );
