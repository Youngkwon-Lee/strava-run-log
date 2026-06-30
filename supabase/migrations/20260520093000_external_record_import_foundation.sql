-- External national / institutional health-record import foundation
-- Phase: raw import first, adoption second
-- Source design: docs/planning/49-national-health-record-fhir-import-lane-v1.md
--                docs/planning/50-tasks-national-health-record-import-v1.md

create table if not exists public.external_record_import_batches (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('myhealthway', 'my-health-record', 'other_fhir')),
  subject_person_id uuid not null references public.persons(id) on delete cascade,
  organization_id uuid null references public.organizations(id) on delete set null,
  requested_by_person_id uuid null references public.persons(id) on delete set null,
  external_patient_id text null,
  external_identifier_system text null,
  external_identifier_value text null,
  from_date date null,
  to_date date null,
  status text not null default 'pending' check (status in ('pending', 'running', 'completed', 'partially_failed', 'failed', 'cancelled')),
  started_at timestamptz null,
  completed_at timestamptz null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_external_record_import_batches_subject_status
  on public.external_record_import_batches(subject_person_id, status, created_at desc);
create index if not exists idx_external_record_import_batches_org_created
  on public.external_record_import_batches(organization_id, created_at desc);
create table if not exists public.external_record_import_resources (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.external_record_import_batches(id) on delete cascade,
  source text not null check (source in ('myhealthway', 'my-health-record', 'other_fhir')),
  resource_type text not null check (resource_type in (
    'Patient',
    'Organization',
    'Practitioner',
    'PractitionerRole',
    'Condition',
    'MedicationRequest',
    'Observation',
    'ImagingStudy',
    'DiagnosticReport',
    'Procedure',
    'AllergyIntolerance',
    'DocumentReference'
  )),
  source_resource_id text null,
  source_version_id text null,
  fingerprint text not null,
  patient_match_person_id uuid null references public.persons(id) on delete set null,
  patient_match_confidence numeric null check (patient_match_confidence >= 0 and patient_match_confidence <= 1),
  patient_match_status text null check (patient_match_status in ('provisional', 'verified', 'rejected')),
  status text not null default 'pending' check (status in ('pending', 'stored', 'duplicate', 'adopted', 'skipped', 'failed')),
  payload_json jsonb not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists external_record_import_resources_batch_fingerprint_unique
  on public.external_record_import_resources(batch_id, fingerprint);
create index if not exists idx_external_record_import_resources_batch_type
  on public.external_record_import_resources(batch_id, resource_type, status);
create index if not exists idx_external_record_import_resources_match_person
  on public.external_record_import_resources(patient_match_person_id, resource_type, created_at desc);
create table if not exists public.external_record_identity_links (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('myhealthway', 'my-health-record', 'other_fhir')),
  external_patient_id text null,
  external_identifier_system text null,
  external_identifier_value text null,
  person_id uuid not null references public.persons(id) on delete cascade,
  confidence numeric not null check (confidence >= 0 and confidence <= 1),
  status text not null default 'provisional' check (status in ('provisional', 'verified', 'rejected')),
  matching_method text not null,
  metadata jsonb not null default '{}'::jsonb,
  last_verified_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint external_record_identity_links_identity_present
    check (external_patient_id is not null or external_identifier_value is not null)
);
create unique index if not exists external_record_identity_links_source_patient_unique
  on public.external_record_identity_links(source, external_patient_id)
  where external_patient_id is not null;
create unique index if not exists external_record_identity_links_source_identifier_unique
  on public.external_record_identity_links(source, external_identifier_system, external_identifier_value)
  where external_identifier_value is not null;
create index if not exists idx_external_record_identity_links_person
  on public.external_record_identity_links(person_id, status, updated_at desc);
create table if not exists public.external_record_adoptions (
  id uuid primary key default gen_random_uuid(),
  import_resource_id uuid not null references public.external_record_import_resources(id) on delete cascade,
  target_table text not null,
  target_id uuid not null,
  status text not null check (status in ('accepted', 'rejected', 'superseded')),
  adopted_by_person_id uuid null references public.persons(id) on delete set null,
  adoption_mode text not null,
  note text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists external_record_adoptions_import_target_unique
  on public.external_record_adoptions(import_resource_id, target_table, target_id);
create index if not exists idx_external_record_adoptions_target
  on public.external_record_adoptions(target_table, target_id, status);
alter table public.external_record_import_batches enable row level security;
alter table public.external_record_import_resources enable row level security;
alter table public.external_record_identity_links enable row level security;
alter table public.external_record_adoptions enable row level security;
create policy external_record_import_batches_org_read
  on public.external_record_import_batches
  for select
  using (
    subject_person_id = public.get_my_person_id()
    or (
      organization_id is not null
      and exists (
        select 1
        from public.organization_members om
        where om.organization_id = external_record_import_batches.organization_id
          and om.person_id = public.get_my_person_id()
      )
    )
  );
create policy external_record_import_batches_org_insert
  on public.external_record_import_batches
  for insert
  with check (
    requested_by_person_id = public.get_my_person_id()
    or (
      organization_id is not null
      and exists (
        select 1
        from public.organization_members om
        where om.organization_id = external_record_import_batches.organization_id
          and om.person_id = public.get_my_person_id()
      )
    )
  );
create policy external_record_import_batches_org_update
  on public.external_record_import_batches
  for update
  using (
    requested_by_person_id = public.get_my_person_id()
    or (
      organization_id is not null
      and exists (
        select 1
        from public.organization_members om
        where om.organization_id = external_record_import_batches.organization_id
          and om.person_id = public.get_my_person_id()
      )
    )
  );
create policy external_record_import_resources_batch_read
  on public.external_record_import_resources
  for select
  using (
    exists (
      select 1
      from public.external_record_import_batches b
      where b.id = external_record_import_resources.batch_id
        and (
          b.subject_person_id = public.get_my_person_id()
          or (
            b.organization_id is not null
            and exists (
              select 1
              from public.organization_members om
              where om.organization_id = b.organization_id
                and om.person_id = public.get_my_person_id()
            )
          )
        )
    )
  );
create policy external_record_import_resources_batch_insert
  on public.external_record_import_resources
  for insert
  with check (
    exists (
      select 1
      from public.external_record_import_batches b
      where b.id = external_record_import_resources.batch_id
        and (
          b.requested_by_person_id = public.get_my_person_id()
          or (
            b.organization_id is not null
            and exists (
              select 1
              from public.organization_members om
              where om.organization_id = b.organization_id
                and om.person_id = public.get_my_person_id()
            )
          )
        )
    )
  );
create policy external_record_import_resources_batch_update
  on public.external_record_import_resources
  for update
  using (
    exists (
      select 1
      from public.external_record_import_batches b
      where b.id = external_record_import_resources.batch_id
        and (
          b.requested_by_person_id = public.get_my_person_id()
          or (
            b.organization_id is not null
            and exists (
              select 1
              from public.organization_members om
              where om.organization_id = b.organization_id
                and om.person_id = public.get_my_person_id()
            )
          )
        )
    )
  );
create policy external_record_identity_links_person_or_org_read
  on public.external_record_identity_links
  for select
  using (
    person_id = public.get_my_person_id()
    or exists (
      select 1
      from public.org_clients oc
      join public.organization_members om
        on om.organization_id = oc.organization_id
      where oc.person_id = external_record_identity_links.person_id
        and om.person_id = public.get_my_person_id()
    )
  );
create policy external_record_identity_links_person_or_org_insert
  on public.external_record_identity_links
  for insert
  with check (
    person_id = public.get_my_person_id()
    or exists (
      select 1
      from public.org_clients oc
      join public.organization_members om
        on om.organization_id = oc.organization_id
      where oc.person_id = external_record_identity_links.person_id
        and om.person_id = public.get_my_person_id()
    )
  );
create policy external_record_identity_links_person_or_org_update
  on public.external_record_identity_links
  for update
  using (
    person_id = public.get_my_person_id()
    or exists (
      select 1
      from public.org_clients oc
      join public.organization_members om
        on om.organization_id = oc.organization_id
      where oc.person_id = external_record_identity_links.person_id
        and om.person_id = public.get_my_person_id()
    )
  );
create policy external_record_adoptions_batch_read
  on public.external_record_adoptions
  for select
  using (
    exists (
      select 1
      from public.external_record_import_resources r
      join public.external_record_import_batches b
        on b.id = r.batch_id
      where r.id = external_record_adoptions.import_resource_id
        and (
          b.subject_person_id = public.get_my_person_id()
          or (
            b.organization_id is not null
            and exists (
              select 1
              from public.organization_members om
              where om.organization_id = b.organization_id
                and om.person_id = public.get_my_person_id()
            )
          )
        )
    )
  );
create policy external_record_adoptions_batch_insert
  on public.external_record_adoptions
  for insert
  with check (
    adopted_by_person_id = public.get_my_person_id()
    or adopted_by_person_id is null
  );
create policy external_record_adoptions_batch_update
  on public.external_record_adoptions
  for update
  using (
    adopted_by_person_id = public.get_my_person_id()
    or adopted_by_person_id is null
  );
drop trigger if exists trg_external_record_import_batches_set_updated_at on public.external_record_import_batches;
create trigger trg_external_record_import_batches_set_updated_at
  before update on public.external_record_import_batches
  for each row
  execute function public.set_updated_at();
drop trigger if exists trg_external_record_import_resources_set_updated_at on public.external_record_import_resources;
create trigger trg_external_record_import_resources_set_updated_at
  before update on public.external_record_import_resources
  for each row
  execute function public.set_updated_at();
drop trigger if exists trg_external_record_identity_links_set_updated_at on public.external_record_identity_links;
create trigger trg_external_record_identity_links_set_updated_at
  before update on public.external_record_identity_links
  for each row
  execute function public.set_updated_at();
drop trigger if exists trg_external_record_adoptions_set_updated_at on public.external_record_adoptions;
create trigger trg_external_record_adoptions_set_updated_at
  before update on public.external_record_adoptions
  for each row
  execute function public.set_updated_at();
