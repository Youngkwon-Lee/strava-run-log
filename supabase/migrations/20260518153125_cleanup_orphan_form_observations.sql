-- Clean up derived form observations/lifecycle events whose source
-- assessment_form_responses rows were deleted, and prevent recurrence.

delete from public.observations obs
where obs.source_type = 'form'
  and obs.form_response_id is not null
  and not exists (
    select 1
    from public.assessment_form_responses afr
    where afr.id = obs.form_response_id
  );
delete from public.person_lifecycle_events ple
where ple.source_table = 'assessment_form_responses'
  and ple.source_id is not null
  and not exists (
    select 1
    from public.assessment_form_responses afr
    where afr.id::text = ple.source_id
  );
alter table public.observations
  drop constraint if exists observations_form_response_id_fkey;
alter table public.observations
  add constraint observations_form_response_id_fkey
  foreign key (form_response_id)
  references public.assessment_form_responses(id)
  on delete cascade
  not valid;
alter table public.observations
  validate constraint observations_form_response_id_fkey;
create or replace function public.trg_cleanup_assessment_response_derivatives()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
  delete from public.person_lifecycle_events
  where source_table = 'assessment_form_responses'
    and source_id = old.id::text;

  return old;
end;
$$;
drop trigger if exists trg_cleanup_assessment_response_derivatives_delete on public.assessment_form_responses;
create trigger trg_cleanup_assessment_response_derivatives_delete
  after delete on public.assessment_form_responses
  for each row
  execute function public.trg_cleanup_assessment_response_derivatives();
with orphan_observations as (
  select count(*)::integer as count
  from public.observations obs
  where obs.source_type = 'form'
    and obs.form_response_id is not null
    and not exists (
      select 1
      from public.assessment_form_responses afr
      where afr.id = obs.form_response_id
    )
),
orphan_lifecycle_events as (
  select count(*)::integer as count
  from public.person_lifecycle_events ple
  where ple.source_table = 'assessment_form_responses'
    and ple.source_id is not null
    and not exists (
      select 1
      from public.assessment_form_responses afr
      where afr.id::text = ple.source_id
    )
)
select
  (select count from orphan_observations) as remaining_orphan_form_observations,
  (select count from orphan_lifecycle_events) as remaining_orphan_assessment_lifecycle_events;
