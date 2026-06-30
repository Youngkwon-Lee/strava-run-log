-- Keep patient_capability_observations in sync with mapped clinical observations.
-- Source of truth remains public.observations; this table/function is a derived projection.

create table if not exists public.movement_capability_observation_mappings (
  id uuid primary key default gen_random_uuid(),
  observation_code text not null,
  observation_code_system text not null default '',
  capability_id uuid not null references public.movement_capabilities(id) on delete cascade,
  default_unit text,
  value_type_hint text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint movement_capability_observation_mappings_code_check check (length(trim(observation_code)) > 0),
  constraint movement_capability_observation_mappings_value_type_check check (
    value_type_hint is null
    or value_type_hint = any (array['quantity','integer','boolean','string','json']::text[])
  ),
  constraint movement_capability_observation_mappings_status_check check (
    status = any (array['draft','active','deprecated']::text[])
  ),
  constraint movement_capability_observation_mappings_unique_key unique (
    observation_code,
    observation_code_system,
    capability_id
  )
);
create index if not exists idx_movement_capability_observation_mappings_code
  on public.movement_capability_observation_mappings (observation_code, observation_code_system, status);
create index if not exists idx_movement_capability_observation_mappings_capability
  on public.movement_capability_observation_mappings (capability_id, status);
drop trigger if exists movement_capability_observation_mappings_set_updated_at
  on public.movement_capability_observation_mappings;
create trigger movement_capability_observation_mappings_set_updated_at
  before update on public.movement_capability_observation_mappings
  for each row execute function public.set_updated_at();
alter table public.movement_capability_observation_mappings enable row level security;
drop policy if exists movement_capability_observation_mappings_read_all
  on public.movement_capability_observation_mappings;
create policy movement_capability_observation_mappings_read_all
  on public.movement_capability_observation_mappings
  for select to authenticated
  using (true);
drop policy if exists movement_capability_observation_mappings_service_write
  on public.movement_capability_observation_mappings;
create policy movement_capability_observation_mappings_service_write
  on public.movement_capability_observation_mappings
  for all to service_role
  using (true)
  with check (true);
with mapping_seed as (
  select * from (values
    ('VAS','pain_activity_nprs','score'),
    ('NPRS','pain_activity_nprs','score'),
    ('ROM_shoulder_flexion','shoulder_flexion_rom','deg'),
    ('ROM_shoulder_external_rotation','shoulder_external_rotation_rom','deg'),
    ('ROM_cervical_flexion','cervical_flexion_rom','deg'),
    ('ROM_cervical_lateral_flexion','cervical_lateral_flexion_rom','deg'),
    ('ROM_cervical_rotation','cervical_rotation_rom','deg'),
    ('ROM_hip_flexion','hip_flexion_rom','deg'),
    ('ROM_knee_flexion','knee_flexion_rom','deg'),
    ('ROM_knee_extension','knee_extension_rom','deg'),
    ('ROM_ankle_dorsiflexion','ankle_dorsiflexion_rom','deg'),
    ('MMT_shoulder_external_rotation','shoulder_external_rotation_strength','grade'),
    ('MMT_hip_abduction','hip_abduction_strength','grade'),
    ('MMT_hip_adduction','hip_adduction_strength','grade'),
    ('MMT_hip_extension','hip_extension_strength','grade'),
    ('MMT_knee_extension','quadriceps_strength','grade'),
    ('MMT_knee_flexion','hamstring_strength','grade'),
    ('grip_strength','grip_strength','grade'),
    ('single_leg_stance_seconds','single_leg_balance_seconds','sec')
  ) as seed(observation_code, capability_code, default_unit)
)
insert into public.movement_capability_observation_mappings (
  observation_code,
  observation_code_system,
  capability_id,
  default_unit,
  value_type_hint,
  metadata,
  status
)
select
  ms.observation_code,
  '',
  mc.id,
  ms.default_unit,
  'quantity',
  jsonb_build_object('seed_wave', 'movement_capability_projection_mvp'),
  'active'
from mapping_seed ms
join public.movement_capabilities mc on mc.capability_code = ms.capability_code
on conflict (observation_code, observation_code_system, capability_id) do update set
  default_unit = excluded.default_unit,
  value_type_hint = excluded.value_type_hint,
  metadata = public.movement_capability_observation_mappings.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
create or replace function private.project_observation_to_patient_capability(p_observation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_upserted_count integer := 0;
begin
  with source_observation as (
    select obs.*
    from public.observations obs
    where obs.id = p_observation_id
  ),
  candidate_projection as (
    select
      obs.organization_id,
      obs.subject_person_id,
      obs.encounter_id,
      obs.id as source_observation_id,
      mapping.capability_id,
      case
        when obs.value_quantity is not null then 'quantity'
        when obs.value_integer is not null then 'quantity'
        when obs.value_json ->> 'numeric_equivalent' ~ '^-?[0-9]+(\.[0-9]+)?$' then 'quantity'
        when obs.value_boolean is not null then 'boolean'
        when obs.value_json is not null then 'json'
        else 'string'
      end as value_type,
      coalesce(
        obs.value_quantity,
        obs.value_integer::numeric,
        case
          when obs.value_json ->> 'numeric_equivalent' ~ '^-?[0-9]+(\.[0-9]+)?$'
            then (obs.value_json ->> 'numeric_equivalent')::numeric
          else null
        end
      ) as value_quantity,
      coalesce(obs.value_unit, mapping.default_unit, mc.default_unit) as value_unit,
      obs.value_boolean,
      obs.value_string,
      obs.value_json,
      obs.effective_datetime,
      obs.created_by,
      obs.code,
      obs.code_system,
      obs.laterality
    from source_observation obs
    join public.movement_capability_observation_mappings mapping
      on mapping.observation_code = obs.code
     and mapping.status = 'active'
     and (
       mapping.observation_code_system = ''
       or mapping.observation_code_system = coalesce(obs.code_system, '')
     )
    join public.movement_capabilities mc
      on mc.id = mapping.capability_id
     and mc.status = 'active'
    where obs.status <> all (array['entered_in_error'::text, 'cancelled'::text])
  ),
  stale_projection as (
    update public.patient_capability_observations pco
    set
      status = 'deprecated',
      updated_at = now(),
      metadata = pco.metadata || jsonb_build_object(
        'deprecated_reason', 'source_observation_no_longer_projects',
        'deprecated_at', now()
      )
    where pco.source_observation_id = p_observation_id
      and pco.status = 'active'
      and not exists (
        select 1
        from candidate_projection candidate
        where candidate.capability_id = pco.capability_id
          and (
            candidate.value_quantity is not null
            or candidate.value_boolean is not null
            or candidate.value_string is not null
            or candidate.value_json is not null
          )
      )
    returning 1
  ),
  upserted_projection as (
    insert into public.patient_capability_observations (
      organization_id,
      subject_person_id,
      encounter_id,
      source_observation_id,
      capability_id,
      value_type,
      value_quantity,
      value_unit,
      value_boolean,
      value_string,
      value_json,
      interpretation,
      confidence,
      source_type,
      effective_datetime,
      metadata,
      status,
      created_by
    )
    select
      candidate.organization_id,
      candidate.subject_person_id,
      candidate.encounter_id,
      candidate.source_observation_id,
      candidate.capability_id,
      candidate.value_type,
      candidate.value_quantity,
      candidate.value_unit,
      candidate.value_boolean,
      candidate.value_string,
      candidate.value_json,
      'unknown',
      1,
      'observation_projection',
      candidate.effective_datetime,
      jsonb_strip_nulls(jsonb_build_object(
        'source_observation_code', candidate.code,
        'source_observation_code_system', candidate.code_system,
        'laterality', candidate.laterality,
        'projection_wave', 'movement_capability_observation_trigger'
      )),
      'active',
      candidate.created_by
    from candidate_projection candidate
    where candidate.value_quantity is not null
       or candidate.value_boolean is not null
       or candidate.value_string is not null
       or candidate.value_json is not null
    on conflict (source_observation_id, capability_id)
      where source_observation_id is not null and status = 'active'
    do update set
      organization_id = excluded.organization_id,
      subject_person_id = excluded.subject_person_id,
      encounter_id = excluded.encounter_id,
      value_type = excluded.value_type,
      value_quantity = excluded.value_quantity,
      value_unit = excluded.value_unit,
      value_boolean = excluded.value_boolean,
      value_string = excluded.value_string,
      value_json = excluded.value_json,
      interpretation = excluded.interpretation,
      confidence = excluded.confidence,
      source_type = excluded.source_type,
      effective_datetime = excluded.effective_datetime,
      metadata = public.patient_capability_observations.metadata || excluded.metadata,
      status = 'active',
      created_by = excluded.created_by,
      updated_at = now()
    returning 1
  )
  select count(*) into v_upserted_count
  from upserted_projection;

  return v_upserted_count;
end;
$$;
comment on function private.project_observation_to_patient_capability(uuid)
  is 'Projects one public.observations row into patient_capability_observations using movement_capability_observation_mappings.';
revoke all on function private.project_observation_to_patient_capability(uuid)
  from public, anon, authenticated;
create or replace function private.trg_project_observation_patient_capability()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if TG_OP = 'DELETE' then
    update public.patient_capability_observations
    set
      status = 'entered_in_error',
      updated_at = now(),
      metadata = metadata || jsonb_build_object(
        'entered_in_error_reason', 'source_observation_deleted',
        'entered_in_error_at', now()
      )
    where source_observation_id = OLD.id
      and status = 'active';

    return OLD;
  end if;

  perform private.project_observation_to_patient_capability(NEW.id);
  return NEW;
end;
$$;
comment on function private.trg_project_observation_patient_capability()
  is 'Trigger wrapper that keeps movement capability projections synchronized for public.observations.';
revoke all on function private.trg_project_observation_patient_capability()
  from public, anon, authenticated;
drop trigger if exists trg_project_observation_patient_capability_insert
  on public.observations;
drop trigger if exists trg_project_observation_patient_capability_update
  on public.observations;
drop trigger if exists trg_project_observation_patient_capability_delete
  on public.observations;
create trigger trg_project_observation_patient_capability_insert
  after insert on public.observations
  for each row
  execute function private.trg_project_observation_patient_capability();
create trigger trg_project_observation_patient_capability_update
  after update of
    status,
    code,
    code_system,
    organization_id,
    subject_person_id,
    encounter_id,
    value_quantity,
    value_unit,
    value_string,
    value_boolean,
    value_integer,
    value_json,
    effective_datetime,
    created_by,
    laterality
  on public.observations
  for each row
  execute function private.trg_project_observation_patient_capability();
create trigger trg_project_observation_patient_capability_delete
  before delete on public.observations
  for each row
  execute function private.trg_project_observation_patient_capability();
select coalesce(sum(private.project_observation_to_patient_capability(obs.id)), 0)
from public.observations obs
where obs.status <> all (array['entered_in_error'::text, 'cancelled'::text])
  and exists (
    select 1
    from public.movement_capability_observation_mappings mapping
    where mapping.observation_code = obs.code
      and mapping.status = 'active'
      and (
        mapping.observation_code_system = ''
        or mapping.observation_code_system = coalesce(obs.code_system, '')
      )
  );
