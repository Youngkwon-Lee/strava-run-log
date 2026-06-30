-- Clean up orphan lifecycle rows for non-assessment source tables and
-- prevent recurrence when source rows are deleted later.

delete from public.person_lifecycle_events ple
where ple.source_table = 'encounters'
  and ple.source_id is not null
  and not exists (
    select 1
    from public.encounters src
    where src.id::text = ple.source_id
  );
delete from public.person_lifecycle_events ple
where ple.source_table = 'booking_events'
  and ple.source_id is not null
  and not exists (
    select 1
    from public.booking_events src
    where src.id::text = ple.source_id
  );
create or replace function private.trg_cleanup_person_lifecycle_source_delete()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
  delete from public.person_lifecycle_events
  where source_table = tg_table_name
    and source_id = old.id::text;

  return old;
end;
$$;
drop trigger if exists trg_cleanup_person_lifecycle_encounter_delete on public.encounters;
create trigger trg_cleanup_person_lifecycle_encounter_delete
  after delete on public.encounters
  for each row
  execute function private.trg_cleanup_person_lifecycle_source_delete();
drop trigger if exists trg_cleanup_person_lifecycle_booking_event_delete on public.booking_events;
create trigger trg_cleanup_person_lifecycle_booking_event_delete
  after delete on public.booking_events
  for each row
  execute function private.trg_cleanup_person_lifecycle_source_delete();
drop trigger if exists trg_cleanup_person_lifecycle_activity_session_delete on public.activity_sessions;
create trigger trg_cleanup_person_lifecycle_activity_session_delete
  after delete on public.activity_sessions
  for each row
  execute function private.trg_cleanup_person_lifecycle_source_delete();
drop trigger if exists trg_cleanup_person_lifecycle_pghd_observation_delete on public.pghd_observations;
create trigger trg_cleanup_person_lifecycle_pghd_observation_delete
  after delete on public.pghd_observations
  for each row
  execute function private.trg_cleanup_person_lifecycle_source_delete();
drop trigger if exists trg_cleanup_person_lifecycle_exercise_prescription_delete on public.exercise_prescriptions;
create trigger trg_cleanup_person_lifecycle_exercise_prescription_delete
  after delete on public.exercise_prescriptions
  for each row
  execute function private.trg_cleanup_person_lifecycle_source_delete();
with orphan_counts as (
  select 'encounters'::text as source_table, count(*)::int as orphan_count
  from public.person_lifecycle_events ple
  where ple.source_table = 'encounters'
    and ple.source_id is not null
    and not exists (
      select 1
      from public.encounters src
      where src.id::text = ple.source_id
    )

  union all

  select 'booking_events'::text as source_table, count(*)::int as orphan_count
  from public.person_lifecycle_events ple
  where ple.source_table = 'booking_events'
    and ple.source_id is not null
    and not exists (
      select 1
      from public.booking_events src
      where src.id::text = ple.source_id
    )

  union all

  select 'activity_sessions'::text as source_table, count(*)::int as orphan_count
  from public.person_lifecycle_events ple
  where ple.source_table = 'activity_sessions'
    and ple.source_id is not null
    and not exists (
      select 1
      from public.activity_sessions src
      where src.id::text = ple.source_id
    )

  union all

  select 'pghd_observations'::text as source_table, count(*)::int as orphan_count
  from public.person_lifecycle_events ple
  where ple.source_table = 'pghd_observations'
    and ple.source_id is not null
    and not exists (
      select 1
      from public.pghd_observations src
      where src.id::text = ple.source_id
    )

  union all

  select 'exercise_prescriptions'::text as source_table, count(*)::int as orphan_count
  from public.person_lifecycle_events ple
  where ple.source_table = 'exercise_prescriptions'
    and ple.source_id is not null
    and not exists (
      select 1
      from public.exercise_prescriptions src
      where src.id::text = ple.source_id
    )
)
select *
from orphan_counts
order by orphan_count desc, source_table;
