-- Phase 2: Episode-aware lifecycle reconciliation
--
-- Purpose:
-- - Preserve append-only source projections while allowing episode linkage
--   to arrive later.
-- - Reconcile person_lifecycle_events when encounter/source rows gain
--   an episode_id after initial projection.
-- - Backfill source rows that can safely inherit episode_id from encounters.

create or replace function public.upsert_person_lifecycle_event(
  p_person_id uuid,
  p_organization_id uuid,
  p_episode_id uuid,
  p_event_family text,
  p_event_type text,
  p_event_kind text,
  p_occurred_at timestamptz,
  p_performed_by text,
  p_actor_person_id uuid,
  p_source_table text,
  p_source_id text,
  p_label text default null,
  p_description text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_id uuid;
begin
  insert into public.person_lifecycle_events (
    person_id,
    organization_id,
    episode_id,
    event_family,
    event_type,
    event_kind,
    occurred_at,
    performed_by,
    actor_person_id,
    source_table,
    source_id,
    label,
    description,
    metadata
  )
  values (
    p_person_id,
    p_organization_id,
    p_episode_id,
    p_event_family,
    p_event_type,
    p_event_kind,
    coalesce(p_occurred_at, now()),
    p_performed_by,
    p_actor_person_id,
    p_source_table,
    p_source_id,
    p_label,
    p_description,
    coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (source_table, source_id, event_kind)
  where source_table is not null and source_id is not null
  do update
    set episode_id = coalesce(public.person_lifecycle_events.episode_id, excluded.episode_id)
  where public.person_lifecycle_events.episode_id is distinct from coalesce(public.person_lifecycle_events.episode_id, excluded.episode_id)
  returning public.person_lifecycle_events.id into v_id;

  if v_id is null and p_source_table is not null and p_source_id is not null then
    select ple.id
      into v_id
    from public.person_lifecycle_events ple
    where ple.source_table = p_source_table
      and ple.source_id = p_source_id
      and ple.event_kind = p_event_kind
    limit 1;
  end if;

  return v_id;
end;
$$;
revoke execute on function public.upsert_person_lifecycle_event(
  uuid, uuid, uuid, text, text, text, timestamptz, text, uuid, text, text, text, text, jsonb
) from public, anon;
grant execute on function public.upsert_person_lifecycle_event(
  uuid, uuid, uuid, text, text, text, timestamptz, text, uuid, text, text, text, text, jsonb
) to authenticated, service_role;
create or replace function public.reconcile_person_lifecycle_event_episode_links_for_encounter(
  p_encounter_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_episode_id uuid;
  v_activity_source_updates integer := 0;
  v_pghd_source_updates integer := 0;
  v_rx_source_updates integer := 0;
  v_encounter_event_updates integer := 0;
  v_assessment_event_updates integer := 0;
  v_activity_event_updates integer := 0;
  v_pghd_event_updates integer := 0;
  v_rx_event_updates integer := 0;
begin
  select e.episode_id
    into v_episode_id
  from public.encounters e
  where e.id = p_encounter_id;

  if v_episode_id is null then
    return jsonb_build_object(
      'encounter_id', p_encounter_id,
      'episode_id', null,
      'activity_source_updates', 0,
      'pghd_source_updates', 0,
      'exercise_prescription_source_updates', 0,
      'encounter_event_updates', 0,
      'assessment_event_updates', 0,
      'activity_event_updates', 0,
      'pghd_event_updates', 0,
      'exercise_prescription_event_updates', 0
    );
  end if;

  update public.activity_sessions act
  set episode_id = v_episode_id,
      updated_at = now()
  where act.encounter_id = p_encounter_id
    and act.episode_id is null;
  get diagnostics v_activity_source_updates = row_count;

  update public.pghd_observations pghd
  set episode_id = v_episode_id,
      updated_at = now()
  where pghd.encounter_id = p_encounter_id
    and pghd.episode_id is null;
  get diagnostics v_pghd_source_updates = row_count;

  update public.exercise_prescriptions rx
  set episode_id = v_episode_id,
      updated_at = now()
  where rx.encounter_id = p_encounter_id
    and rx.episode_id is null;
  get diagnostics v_rx_source_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = v_episode_id
  where ple.source_table = 'encounters'
    and ple.source_id = p_encounter_id::text
    and ple.episode_id is distinct from v_episode_id;
  get diagnostics v_encounter_event_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = v_episode_id
  from public.assessment_form_responses afr
  where ple.source_table = 'assessment_form_responses'
    and ple.source_id = afr.id::text
    and afr.encounter_id = p_encounter_id
    and ple.episode_id is distinct from v_episode_id;
  get diagnostics v_assessment_event_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = v_episode_id
  from public.activity_sessions act
  where ple.source_table = 'activity_sessions'
    and ple.source_id = act.id::text
    and act.encounter_id = p_encounter_id
    and ple.episode_id is distinct from v_episode_id;
  get diagnostics v_activity_event_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = v_episode_id
  from public.pghd_observations pghd
  where ple.source_table = 'pghd_observations'
    and ple.source_id = pghd.id::text
    and pghd.encounter_id = p_encounter_id
    and ple.episode_id is distinct from v_episode_id;
  get diagnostics v_pghd_event_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = v_episode_id
  from public.exercise_prescriptions rx
  where ple.source_table = 'exercise_prescriptions'
    and ple.source_id = rx.id::text
    and rx.encounter_id = p_encounter_id
    and ple.episode_id is distinct from v_episode_id;
  get diagnostics v_rx_event_updates = row_count;

  return jsonb_build_object(
    'encounter_id', p_encounter_id,
    'episode_id', v_episode_id,
    'activity_source_updates', v_activity_source_updates,
    'pghd_source_updates', v_pghd_source_updates,
    'exercise_prescription_source_updates', v_rx_source_updates,
    'encounter_event_updates', v_encounter_event_updates,
    'assessment_event_updates', v_assessment_event_updates,
    'activity_event_updates', v_activity_event_updates,
    'pghd_event_updates', v_pghd_event_updates,
    'exercise_prescription_event_updates', v_rx_event_updates
  );
end;
$$;
revoke execute on function public.reconcile_person_lifecycle_event_episode_links_for_encounter(uuid) from public, anon;
grant execute on function public.reconcile_person_lifecycle_event_episode_links_for_encounter(uuid) to authenticated, service_role;
create or replace function public.reconcile_all_person_lifecycle_event_episode_links()
returns jsonb
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_activity_source_updates integer := 0;
  v_pghd_source_updates integer := 0;
  v_rx_source_updates integer := 0;
  v_encounter_event_updates integer := 0;
  v_assessment_event_updates integer := 0;
  v_activity_event_updates integer := 0;
  v_pghd_event_updates integer := 0;
  v_rx_event_updates integer := 0;
begin
  update public.activity_sessions act
  set episode_id = enc.episode_id,
      updated_at = now()
  from public.encounters enc
  where act.encounter_id = enc.id
    and act.episode_id is null
    and enc.episode_id is not null;
  get diagnostics v_activity_source_updates = row_count;

  update public.pghd_observations pghd
  set episode_id = enc.episode_id,
      updated_at = now()
  from public.encounters enc
  where pghd.encounter_id = enc.id
    and pghd.episode_id is null
    and enc.episode_id is not null;
  get diagnostics v_pghd_source_updates = row_count;

  update public.exercise_prescriptions rx
  set episode_id = enc.episode_id,
      updated_at = now()
  from public.encounters enc
  where rx.encounter_id = enc.id
    and rx.episode_id is null
    and enc.episode_id is not null;
  get diagnostics v_rx_source_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = enc.episode_id
  from public.encounters enc
  where ple.source_table = 'encounters'
    and ple.source_id = enc.id::text
    and enc.episode_id is not null
    and ple.episode_id is distinct from enc.episode_id;
  get diagnostics v_encounter_event_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = enc.episode_id
  from public.assessment_form_responses afr
  join public.encounters enc
    on enc.id = afr.encounter_id
  where ple.source_table = 'assessment_form_responses'
    and ple.source_id = afr.id::text
    and enc.episode_id is not null
    and ple.episode_id is distinct from enc.episode_id;
  get diagnostics v_assessment_event_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = coalesce(act.episode_id, enc.episode_id)
  from public.activity_sessions act
  left join public.encounters enc
    on enc.id = act.encounter_id
  where ple.source_table = 'activity_sessions'
    and ple.source_id = act.id::text
    and coalesce(act.episode_id, enc.episode_id) is not null
    and ple.episode_id is distinct from coalesce(act.episode_id, enc.episode_id);
  get diagnostics v_activity_event_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = coalesce(pghd.episode_id, enc.episode_id)
  from public.pghd_observations pghd
  left join public.encounters enc
    on enc.id = pghd.encounter_id
  where ple.source_table = 'pghd_observations'
    and ple.source_id = pghd.id::text
    and coalesce(pghd.episode_id, enc.episode_id) is not null
    and ple.episode_id is distinct from coalesce(pghd.episode_id, enc.episode_id);
  get diagnostics v_pghd_event_updates = row_count;

  update public.person_lifecycle_events ple
  set episode_id = coalesce(rx.episode_id, enc.episode_id)
  from public.exercise_prescriptions rx
  left join public.encounters enc
    on enc.id = rx.encounter_id
  where ple.source_table = 'exercise_prescriptions'
    and ple.source_id = rx.id::text
    and coalesce(rx.episode_id, enc.episode_id) is not null
    and ple.episode_id is distinct from coalesce(rx.episode_id, enc.episode_id);
  get diagnostics v_rx_event_updates = row_count;

  return jsonb_build_object(
    'activity_source_updates', v_activity_source_updates,
    'pghd_source_updates', v_pghd_source_updates,
    'exercise_prescription_source_updates', v_rx_source_updates,
    'encounter_event_updates', v_encounter_event_updates,
    'assessment_event_updates', v_assessment_event_updates,
    'activity_event_updates', v_activity_event_updates,
    'pghd_event_updates', v_pghd_event_updates,
    'exercise_prescription_event_updates', v_rx_event_updates
  );
end;
$$;
revoke execute on function public.reconcile_all_person_lifecycle_event_episode_links() from public, anon;
grant execute on function public.reconcile_all_person_lifecycle_event_episode_links() to authenticated, service_role;
create or replace function public.trg_reconcile_lifecycle_from_encounter_episode_update()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
begin
  if NEW.episode_id is not null and NEW.episode_id is distinct from OLD.episode_id then
    perform public.reconcile_person_lifecycle_event_episode_links_for_encounter(NEW.id);
  end if;

  return NEW;
end;
$$;
revoke execute on function public.trg_reconcile_lifecycle_from_encounter_episode_update() from public, anon;
grant execute on function public.trg_reconcile_lifecycle_from_encounter_episode_update() to authenticated, service_role;
drop trigger if exists trg_lifecycle_reconcile_encounter_episode_update on public.encounters;
create trigger trg_lifecycle_reconcile_encounter_episode_update
  after update of episode_id on public.encounters
  for each row
  when (OLD.episode_id is distinct from NEW.episode_id)
  execute function public.trg_reconcile_lifecycle_from_encounter_episode_update();
drop trigger if exists trg_lifecycle_project_activity_session_episode_update on public.activity_sessions;
create trigger trg_lifecycle_project_activity_session_episode_update
  after update of episode_id on public.activity_sessions
  for each row
  when (OLD.episode_id is distinct from NEW.episode_id and NEW.episode_id is not null)
  execute function public.trg_project_lifecycle_from_activity_session();
drop trigger if exists trg_lifecycle_project_pghd_observation_episode_update on public.pghd_observations;
create trigger trg_lifecycle_project_pghd_observation_episode_update
  after update of episode_id on public.pghd_observations
  for each row
  when (OLD.episode_id is distinct from NEW.episode_id and NEW.episode_id is not null)
  execute function public.trg_project_lifecycle_from_pghd_observation();
select public.reconcile_all_person_lifecycle_event_episode_links();
