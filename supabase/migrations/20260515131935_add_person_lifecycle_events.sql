-- Person lifecycle event foundation
--
-- Purpose:
-- - Add a person-centered event stream above episodes.
-- - Keep person_events as identity/profile audit, and clinical_events as PHI/security audit.
-- - Preserve domain events that can open, close, or contextualize episodes:
--   intake, episode start/end, encounter, assessment, activity, competition, PGHD, etc.

-- ---------------------------------------------------------------------------
-- 1. Normalize assessment_form_responses.source_type vocabulary.
-- ---------------------------------------------------------------------------

update public.assessment_form_responses
set source_type = 'patient_self'
where source_type = 'patient_self_report';
update public.assessment_form_responses
set source_type = 'clinical'
where source_type in ('clinician', 'manual');
-- Earlier beta activity rows can carry generated organization IDs that were
-- never persisted. Normalize them before adding the lifecycle stream FK path.
update public.activity_sessions act
set organization_id = null,
    updated_at = now()
where act.organization_id is not null
  and not exists (
    select 1
    from public.organizations org
    where org.id = act.organization_id
  );
alter table public.assessment_form_responses
  alter column source_type set default 'clinical';
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'assessment_form_responses_source_type_check'
      and conrelid = 'public.assessment_form_responses'::regclass
  ) then
    alter table public.assessment_form_responses
      add constraint assessment_form_responses_source_type_check
      check (
        source_type is null
        or source_type in ('clinical', 'patient_self', 'intake_form', 'import', 'system')
      )
      not valid;
	  end if;
	end $$;
alter table public.assessment_form_responses
  validate constraint assessment_form_responses_source_type_check;
drop policy if exists "afr_insert_consolidated" on public.assessment_form_responses;
create policy "afr_insert_consolidated"
  on public.assessment_form_responses
  for insert
  with check (
    exists (
      select 1
      from public.organization_members om
      where om.person_id = public.get_my_person_id()
        and om.organization_id = assessment_form_responses.organization_id
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text])
        and om.status = 'active'
    )
    or (
      source_type in ('patient_self', 'intake_form')
      and subject_person_id = public.get_my_person_id()
      and performer_person_id = subject_person_id
      and organization_id is null
    )
  );
drop policy if exists "afr_select_consolidated" on public.assessment_form_responses;
create policy "afr_select_consolidated"
  on public.assessment_form_responses
  for select
  using (
    (
      source_type in ('patient_self', 'intake_form')
      and exists (
        select 1
        from public.org_clients oc
        join public.organization_members om
          on om.organization_id = oc.organization_id
        where oc.person_id = assessment_form_responses.subject_person_id
          and om.person_id = public.get_my_person_id()
          and om.status = 'active'
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
    or exists (
      select 1
      from public.organization_members om
      where om.organization_id = assessment_form_responses.organization_id
        and om.person_id = public.get_my_person_id()
        and om.status = 'active'
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
    )
    or exists (
      select 1
      from public.match_results mr
      where mr.client_person_id = assessment_form_responses.subject_person_id
        and mr.provider_person_id = public.get_my_person_id()
        and mr.status = 'accepted'
    )
    or (
      source_type in ('patient_self', 'intake_form')
      and subject_person_id = public.get_my_person_id()
    )
  );
-- ---------------------------------------------------------------------------
-- 2. Add person_lifecycle_events as the domain event stream above episodes.
-- ---------------------------------------------------------------------------

create table if not exists public.person_lifecycle_events (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.persons(id),
  organization_id uuid references public.organizations(id) on delete set null,
  episode_id uuid references public.episodes(id) on delete set null,
  event_family text not null,
  event_type text not null,
  event_kind text not null,
  occurred_at timestamptz not null default now(),
  performed_by text not null default 'system',
  actor_person_id uuid references public.persons(id) on delete set null,
  source_table text,
  source_id text,
  label text,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint person_lifecycle_events_family_check
    check (event_family in ('clinical', 'training', 'wellness', 'assessment', 'pghd', 'scheduling', 'life', 'admin')),
  constraint person_lifecycle_events_performed_by_check
    check (performed_by in ('provider', 'patient', 'device', 'system', 'integration', 'ai')),
  constraint person_lifecycle_events_nonempty_type_check
    check (length(trim(event_type)) > 0 and length(trim(event_kind)) > 0),
  constraint person_lifecycle_events_source_pair_check
    check ((source_table is null and source_id is null) or (source_table is not null and source_id is not null))
);
comment on table public.person_lifecycle_events is
  'Person-centered domain event stream above episodes. Use for clinical, training, wellness, assessment, PGHD, scheduling, and life-course events that may contextualize one or more episodes.';
comment on column public.person_lifecycle_events.episode_id is
  'Optional episode link. Events can exist before an episode, create an episode, or remain person-level.';
comment on column public.person_lifecycle_events.source_table is
  'Original source table when this row is a durable projection of another source record.';
comment on column public.person_lifecycle_events.source_id is
  'Original source primary key as text, allowing UUID or integer-backed sources.';
create index if not exists idx_person_lifecycle_events_person_time
  on public.person_lifecycle_events (person_id, occurred_at desc);
create index if not exists idx_person_lifecycle_events_org_person_time
  on public.person_lifecycle_events (organization_id, person_id, occurred_at desc)
  where organization_id is not null;
create index if not exists idx_person_lifecycle_events_episode_time
  on public.person_lifecycle_events (episode_id, occurred_at desc)
  where episode_id is not null;
create index if not exists idx_person_lifecycle_events_kind_time
  on public.person_lifecycle_events (event_family, event_kind, occurred_at desc);
create unique index if not exists uq_person_lifecycle_events_source
  on public.person_lifecycle_events (source_table, source_id, event_kind)
  where source_table is not null and source_id is not null;
alter table public.person_lifecycle_events enable row level security;
revoke all on table public.person_lifecycle_events from anon;
grant select, insert on table public.person_lifecycle_events to authenticated;
grant select, insert, update, delete on table public.person_lifecycle_events to service_role;
drop policy if exists "person_lifecycle_events_select" on public.person_lifecycle_events;
create policy "person_lifecycle_events_select"
  on public.person_lifecycle_events
  for select
  to authenticated
  using (
    person_id = public.get_my_person_id()
    or (
      organization_id is not null
      and exists (
        select 1
        from public.organization_members om
        where om.organization_id = person_lifecycle_events.organization_id
          and om.person_id = public.get_my_person_id()
          and om.status = 'active'
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
    or exists (
      select 1
      from public.org_clients oc
      join public.organization_members om
        on om.organization_id = oc.organization_id
      where oc.person_id = person_lifecycle_events.person_id
        and om.person_id = public.get_my_person_id()
        and om.status = 'active'
        and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
    )
  );
drop policy if exists "person_lifecycle_events_insert" on public.person_lifecycle_events;
create policy "person_lifecycle_events_insert"
  on public.person_lifecycle_events
  for insert
  to authenticated
  with check (
    (
      person_id = public.get_my_person_id()
      and performed_by in ('patient', 'device', 'integration')
    )
    or (
      organization_id is not null
      and exists (
        select 1
        from public.organization_members om
        where om.organization_id = person_lifecycle_events.organization_id
          and om.person_id = public.get_my_person_id()
          and om.status = 'active'
          and om.role = any (array['owner'::text, 'admin'::text, 'provider'::text, 'staff'::text])
      )
    )
  );
drop policy if exists "person_lifecycle_events_service_role_all" on public.person_lifecycle_events;
create policy "person_lifecycle_events_service_role_all"
  on public.person_lifecycle_events
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
-- ---------------------------------------------------------------------------
-- 3. Project source records into person_lifecycle_events.
-- ---------------------------------------------------------------------------

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
  do nothing
  returning id into v_id;

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
create or replace function public.trg_project_lifecycle_from_encounter()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_event_kind text;
  v_label text;
begin
  if TG_OP = 'INSERT' then
    v_event_kind := 'encounter.created';
    v_label := '세션 생성';
  elsif TG_OP = 'UPDATE' and NEW.status is distinct from OLD.status then
    if NEW.status = 'finished' then
      v_event_kind := case NEW.session_type
        when 'discharge' then 'encounter.discharge'
        when 'reassessment' then 'encounter.reassessment'
        else 'encounter.finished'
      end;
      v_label := case NEW.session_type
        when 'discharge' then '퇴원'
        when 'reassessment' then '재평가'
        else '세션 완료'
      end;
    elsif NEW.status = 'cancelled' then
      v_event_kind := 'encounter.cancelled';
      v_label := '세션 취소';
    else
      return NEW;
    end if;
  else
    return NEW;
  end if;

  perform public.upsert_person_lifecycle_event(
    NEW.subject_person_id,
    NEW.organization_id,
    NEW.episode_id,
    'clinical',
    'encounter',
    v_event_kind,
    NEW.period_start,
    'provider',
    NEW.provider_person_id,
    'encounters',
    NEW.id::text,
    v_label,
    NEW.chief_complaint,
    jsonb_build_object(
      'status', NEW.status,
      'session_type', NEW.session_type,
      'service_domain', NEW.service_domain,
      'care_setting', NEW.care_setting,
      'visit_number', NEW.visit_number,
      'period_end', NEW.period_end
    )
  );

  return NEW;
end;
$$;
revoke execute on function public.trg_project_lifecycle_from_encounter() from public, anon;
grant execute on function public.trg_project_lifecycle_from_encounter() to authenticated, service_role;
drop trigger if exists trg_lifecycle_project_encounter_insert on public.encounters;
create trigger trg_lifecycle_project_encounter_insert
  after insert on public.encounters
  for each row
  execute function public.trg_project_lifecycle_from_encounter();
drop trigger if exists trg_lifecycle_project_encounter_status on public.encounters;
create trigger trg_lifecycle_project_encounter_status
  after update of status on public.encounters
  for each row
  when (OLD.status is distinct from NEW.status)
  execute function public.trg_project_lifecycle_from_encounter();
create or replace function public.trg_project_lifecycle_from_assessment()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_source_type text := coalesce(NEW.source_type::text, 'clinical');
  v_episode_id uuid;
  v_event_type text;
  v_event_kind text;
  v_performed_by text;
  v_label text;
begin
  select e.episode_id
    into v_episode_id
  from public.encounters e
  where e.id = NEW.encounter_id;

  if v_source_type in ('patient_self', 'patient_self_report') then
    v_event_type := 'self_assessment';
    v_event_kind := 'assessment.self';
    v_performed_by := 'patient';
    v_label := '자가평가';
  elsif v_source_type = 'intake_form' then
    v_event_type := 'intake_assessment';
    v_event_kind := 'assessment.intake';
    v_performed_by := 'patient';
    v_label := '인테이크';
  else
    v_event_type := 'clinical_assessment';
    v_event_kind := 'assessment.clinical';
    v_performed_by := 'provider';
    v_label := '전문가 평가';
  end if;

  perform public.upsert_person_lifecycle_event(
    NEW.subject_person_id,
    NEW.organization_id,
    v_episode_id,
    'assessment',
    v_event_type,
    v_event_kind,
    coalesce(NEW.assessment_date, NEW.created_at),
    v_performed_by,
    NEW.performer_person_id,
    'assessment_form_responses',
    NEW.id::text,
    v_label,
    NEW.notes,
    jsonb_build_object(
      'form_template_id', NEW.form_template_id,
      'source_type', v_source_type,
      'total_score', NEW.total_score,
      'mcid_status', NEW.mcid_status,
      'encounter_id', NEW.encounter_id
    )
  );

  return NEW;
end;
$$;
revoke execute on function public.trg_project_lifecycle_from_assessment() from public, anon;
grant execute on function public.trg_project_lifecycle_from_assessment() to authenticated, service_role;
drop trigger if exists trg_lifecycle_project_assessment_insert on public.assessment_form_responses;
create trigger trg_lifecycle_project_assessment_insert
  after insert on public.assessment_form_responses
  for each row
  execute function public.trg_project_lifecycle_from_assessment();
create or replace function public.trg_project_lifecycle_from_activity_session()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_event_type text;
  v_event_kind text;
  v_event_family text;
  v_performed_by text;
  v_label text;
begin
  v_event_type := case NEW.activity_type
    when 'clinic_exercise' then 'clinic_exercise'
    when 'gym_training' then 'gym_session'
    when 'competition' then 'competition'
    when 'group_class' then 'group_class'
    when 'daily_walk' then 'daily_walk'
    when 'telehealth' then 'telehealth'
    when 'assessment' then 'activity_assessment'
    else 'home_exercise'
  end;

  v_event_kind := case NEW.activity_type
    when 'clinic_exercise' then 'activity.clinic_exercise'
    when 'gym_training' then 'activity.gym_session'
    when 'competition' then 'activity.competition'
    when 'group_class' then 'activity.group_class'
    when 'daily_walk' then 'activity.daily_walk'
    when 'telehealth' then 'activity.telehealth'
    when 'assessment' then 'activity.assessment'
    when 'other' then 'activity.other'
    else 'activity.home_exercise'
  end;

  v_event_family := case NEW.activity_type
    when 'daily_walk' then 'wellness'
    when 'other' then 'wellness'
    when 'assessment' then 'assessment'
    when 'telehealth' then 'clinical'
    else 'training'
  end;

  v_performed_by := case
    when NEW.source in ('apple_health', 'samsung_health', 'garmin', 'imu', 'camera') then 'device'
    else 'patient'
  end;

  v_label := case NEW.activity_type
    when 'home_exercise' then '홈운동'
    when 'clinic_exercise' then '클리닉 운동'
    when 'gym_training' then '헬스장'
    when 'competition' then '대회'
    when 'group_class' then '그룹 수업'
    when 'daily_walk' then '걷기'
    when 'telehealth' then '원격 활동'
    when 'assessment' then '활동 평가'
    else '활동'
  end;

  perform public.upsert_person_lifecycle_event(
    NEW.subject_person_id,
    NEW.organization_id,
    NEW.episode_id,
    v_event_family,
    v_event_type,
    v_event_kind,
    NEW.performed_at,
    v_performed_by,
    NEW.created_by,
    'activity_sessions',
    NEW.id::text,
    v_label,
    NEW.notes,
    jsonb_build_object(
      'activity_type', NEW.activity_type,
      'source', NEW.source,
      'status', NEW.status,
      'duration_seconds', NEW.duration_seconds,
      'encounter_id', NEW.encounter_id,
      'care_plan_id', NEW.care_plan_id,
      'has_timeseries', NEW.has_timeseries,
      'metrics', NEW.metrics
    )
  );

  return NEW;
end;
$$;
revoke execute on function public.trg_project_lifecycle_from_activity_session() from public, anon;
grant execute on function public.trg_project_lifecycle_from_activity_session() to authenticated, service_role;
drop trigger if exists trg_lifecycle_project_activity_session_insert on public.activity_sessions;
create trigger trg_lifecycle_project_activity_session_insert
  after insert on public.activity_sessions
  for each row
  execute function public.trg_project_lifecycle_from_activity_session();
create or replace function public.trg_project_lifecycle_from_pghd_observation()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
begin
  perform public.upsert_person_lifecycle_event(
    NEW.person_id,
    null,
    NEW.episode_id,
    'pghd',
    'wearable_sync',
    'pghd.sync',
    NEW.effective_datetime,
    case when NEW.data_source = 'manual' then 'patient' else 'device' end,
    NEW.verified_by,
    'pghd_observations',
    NEW.id::text,
    NEW.observation_type,
    case
      when NEW.value_quantity is not null then concat(NEW.value_quantity::text, coalesce(NEW.value_unit, ''))
      else NEW.value_string
    end,
    jsonb_build_object(
      'observation_type', NEW.observation_type,
      'data_source', NEW.data_source,
      'source_device', NEW.source_device,
      'source_app', NEW.source_app,
      'value_quantity', NEW.value_quantity,
      'value_unit', NEW.value_unit,
      'verification_status', NEW.verification_status,
      'data_quality_score', NEW.data_quality_score,
      'encounter_id', NEW.encounter_id,
      'activity_session_id', NEW.activity_session_id
    )
  );

  return NEW;
end;
$$;
revoke execute on function public.trg_project_lifecycle_from_pghd_observation() from public, anon;
grant execute on function public.trg_project_lifecycle_from_pghd_observation() to authenticated, service_role;
drop trigger if exists trg_lifecycle_project_pghd_observation_insert on public.pghd_observations;
create trigger trg_lifecycle_project_pghd_observation_insert
  after insert on public.pghd_observations
  for each row
  execute function public.trg_project_lifecycle_from_pghd_observation();
create or replace function public.trg_project_lifecycle_from_exercise_prescription()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_event_kind text;
  v_label text;
begin
  if TG_OP = 'INSERT' then
    v_event_kind := 'prescription.created';
    v_label := '운동 처방';
  elsif TG_OP = 'UPDATE' and NEW.status is distinct from OLD.status then
    v_event_kind := case NEW.status
      when 'completed' then 'prescription.completed'
      when 'paused' then 'prescription.paused'
      when 'discontinued' then 'prescription.cancelled'
      else 'prescription.updated'
    end;
    v_label := case NEW.status
      when 'completed' then '운동 처방 완료'
      when 'paused' then '운동 처방 일시중지'
      when 'discontinued' then '운동 처방 중단'
      else '운동 처방 변경'
    end;
  else
    return NEW;
  end if;

  perform public.upsert_person_lifecycle_event(
    NEW.subject_person_id,
    NEW.organization_id,
    NEW.episode_id,
    'clinical',
    'exercise_prescription',
    v_event_kind,
    NEW.created_at,
    'provider',
    NEW.created_by,
    'exercise_prescriptions',
    NEW.id::text,
    v_label,
    NEW.notes,
    jsonb_build_object(
      'exercise_id', NEW.exercise_id,
      'encounter_id', NEW.encounter_id,
      'status', NEW.status,
      'phase', NEW.phase,
      'frequency', NEW.frequency,
      'frequency_per_week', NEW.frequency_per_week,
      'duration_weeks', NEW.duration_weeks,
      'rpe_target', NEW.rpe_target
    )
  );

  return NEW;
end;
$$;
revoke execute on function public.trg_project_lifecycle_from_exercise_prescription() from public, anon;
grant execute on function public.trg_project_lifecycle_from_exercise_prescription() to authenticated, service_role;
drop trigger if exists trg_lifecycle_project_exercise_prescription_insert on public.exercise_prescriptions;
create trigger trg_lifecycle_project_exercise_prescription_insert
  after insert on public.exercise_prescriptions
  for each row
  execute function public.trg_project_lifecycle_from_exercise_prescription();
drop trigger if exists trg_lifecycle_project_exercise_prescription_status on public.exercise_prescriptions;
create trigger trg_lifecycle_project_exercise_prescription_status
  after update of status on public.exercise_prescriptions
  for each row
  when (OLD.status is distinct from NEW.status)
  execute function public.trg_project_lifecycle_from_exercise_prescription();
create or replace function public.trg_project_lifecycle_from_booking_event()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_booking record;
  v_event_kind text;
  v_label text;
  v_performed_by text;
begin
  select b.subject_person_id, b.scheduled_at, b.service_type, b.status
    into v_booking
  from public.bookings b
  where b.id = NEW.booking_id;

  if not found then
    return NEW;
  end if;

  v_event_kind := case NEW.event_type
    when 'BOOKING_CREATED' then 'booking.created'
    when 'CREATED' then 'booking.created'
    when 'CONFIRMED' then 'booking.confirmed'
    when 'REJECTED' then 'booking.rejected'
    when 'COMPLETED' then 'booking.completed'
    when 'CANCELLED' then 'booking.cancelled'
    when 'CANCELLED_BY_PROFESSIONAL' then 'booking.cancelled'
    when 'CANCELLED_BY_PATIENT' then 'booking.cancelled'
    when 'NO_SHOW' then 'booking.no_show'
    when 'RESCHEDULED' then 'booking.rescheduled'
    else 'booking.updated'
  end;

  v_label := case v_event_kind
    when 'booking.created' then '예약 생성'
    when 'booking.confirmed' then '예약 확정'
    when 'booking.rejected' then '예약 거절'
    when 'booking.completed' then '예약 완료'
    when 'booking.cancelled' then '예약 취소'
    when 'booking.no_show' then '노쇼'
    when 'booking.rescheduled' then '예약 변경'
    else '예약 이벤트'
  end;

  v_performed_by := case NEW.actor_type
    when 'patient' then 'patient'
    when 'professional' then 'provider'
    when 'admin' then 'provider'
    else 'system'
  end;

  perform public.upsert_person_lifecycle_event(
    v_booking.subject_person_id,
    NEW.organization_id,
    null,
    'scheduling',
    'booking',
    v_event_kind,
    coalesce(NEW.created_at, v_booking.scheduled_at),
    v_performed_by,
    NEW.actor_person_id,
    'booking_events',
    NEW.id::text,
    v_label,
    concat_ws(' · ', v_booking.service_type, v_booking.scheduled_at::text),
    jsonb_build_object(
      'booking_id', NEW.booking_id,
      'booking_event_type', NEW.event_type,
      'booking_status', v_booking.status,
      'scheduled_at', v_booking.scheduled_at,
      'service_type', v_booking.service_type,
      'payload', NEW.payload
    )
  );

  return NEW;
end;
$$;
revoke execute on function public.trg_project_lifecycle_from_booking_event() from public, anon;
grant execute on function public.trg_project_lifecycle_from_booking_event() to authenticated, service_role;
drop trigger if exists trg_lifecycle_project_booking_event_insert on public.booking_events;
create trigger trg_lifecycle_project_booking_event_insert
  after insert on public.booking_events
  for each row
  execute function public.trg_project_lifecycle_from_booking_event();
-- ---------------------------------------------------------------------------
-- 4. Harden activity_sessions referential integrity for exercise/competition.
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_sessions_subject_person_id_fkey'
      and conrelid = 'public.activity_sessions'::regclass
  ) then
    alter table public.activity_sessions
      add constraint activity_sessions_subject_person_id_fkey
      foreign key (subject_person_id) references public.persons(id)
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_sessions_organization_id_fkey'
      and conrelid = 'public.activity_sessions'::regclass
  ) then
    alter table public.activity_sessions
      add constraint activity_sessions_organization_id_fkey
      foreign key (organization_id) references public.organizations(id) on delete set null
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_sessions_episode_id_fkey'
      and conrelid = 'public.activity_sessions'::regclass
  ) then
    alter table public.activity_sessions
      add constraint activity_sessions_episode_id_fkey
      foreign key (episode_id) references public.episodes(id) on delete set null
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_sessions_encounter_id_fkey'
      and conrelid = 'public.activity_sessions'::regclass
  ) then
    alter table public.activity_sessions
      add constraint activity_sessions_encounter_id_fkey
      foreign key (encounter_id) references public.encounters(id) on delete set null
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_sessions_care_plan_id_fkey'
      and conrelid = 'public.activity_sessions'::regclass
  ) then
    alter table public.activity_sessions
      add constraint activity_sessions_care_plan_id_fkey
      foreign key (care_plan_id) references public.care_plans(id) on delete set null
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'activity_sessions_created_by_fkey'
      and conrelid = 'public.activity_sessions'::regclass
  ) then
    alter table public.activity_sessions
      add constraint activity_sessions_created_by_fkey
      foreign key (created_by) references public.persons(id) on delete set null
      not valid;
  end if;
end $$;
alter table public.activity_sessions
  validate constraint activity_sessions_subject_person_id_fkey;
alter table public.activity_sessions
  validate constraint activity_sessions_organization_id_fkey;
alter table public.activity_sessions
  validate constraint activity_sessions_episode_id_fkey;
alter table public.activity_sessions
  validate constraint activity_sessions_encounter_id_fkey;
alter table public.activity_sessions
  validate constraint activity_sessions_care_plan_id_fkey;
alter table public.activity_sessions
  validate constraint activity_sessions_created_by_fkey;
create index if not exists idx_activity_sessions_org_subject_performed
  on public.activity_sessions (organization_id, subject_person_id, performed_at desc)
  where organization_id is not null;
-- ---------------------------------------------------------------------------
-- 5. Backfill existing durable source records into the lifecycle stream.
-- ---------------------------------------------------------------------------

select count(*) as backfilled_encounter_created
from (
select public.upsert_person_lifecycle_event(
  e.subject_person_id,
  e.organization_id,
  e.episode_id,
  'clinical',
  'encounter',
  'encounter.created',
  e.period_start,
  'provider',
  e.provider_person_id,
  'encounters',
  e.id::text,
  '세션 생성',
  e.chief_complaint,
  jsonb_build_object(
    'status', e.status,
    'session_type', e.session_type,
    'service_domain', e.service_domain,
    'care_setting', e.care_setting,
    'visit_number', e.visit_number,
    'period_end', e.period_end
  )
)
from public.encounters e
where e.deleted_at is null
) projected;
select count(*) as backfilled_encounter_terminal
from (
select public.upsert_person_lifecycle_event(
  e.subject_person_id,
  e.organization_id,
  e.episode_id,
  'clinical',
  'encounter',
  case e.status
    when 'finished' then case e.session_type
      when 'discharge' then 'encounter.discharge'
      when 'reassessment' then 'encounter.reassessment'
      else 'encounter.finished'
    end
    when 'cancelled' then 'encounter.cancelled'
    else 'encounter.status_changed'
  end,
  coalesce(e.period_end, e.period_start),
  'provider',
  e.provider_person_id,
  'encounters',
  e.id::text,
  case e.status
    when 'finished' then case e.session_type
      when 'discharge' then '퇴원'
      when 'reassessment' then '재평가'
      else '세션 완료'
    end
    when 'cancelled' then '세션 취소'
    else '세션 상태 변경'
  end,
  e.chief_complaint,
  jsonb_build_object(
    'status', e.status,
    'session_type', e.session_type,
    'service_domain', e.service_domain,
    'care_setting', e.care_setting,
    'visit_number', e.visit_number,
    'period_end', e.period_end
  )
)
from public.encounters e
where e.deleted_at is null
  and e.status in ('finished', 'cancelled')
) projected;
select count(*) as backfilled_assessment
from (
select public.upsert_person_lifecycle_event(
  afr.subject_person_id,
  afr.organization_id,
  enc.episode_id,
  'assessment',
  case
    when afr.source_type::text in ('patient_self', 'patient_self_report') then 'self_assessment'
    when afr.source_type::text = 'intake_form' then 'intake_assessment'
    else 'clinical_assessment'
  end,
  case
    when afr.source_type::text in ('patient_self', 'patient_self_report') then 'assessment.self'
    when afr.source_type::text = 'intake_form' then 'assessment.intake'
    else 'assessment.clinical'
  end,
  coalesce(afr.assessment_date, afr.created_at),
  case
    when afr.source_type::text in ('patient_self', 'patient_self_report', 'intake_form') then 'patient'
    else 'provider'
  end,
  afr.performer_person_id,
  'assessment_form_responses',
  afr.id::text,
  case
    when afr.source_type::text in ('patient_self', 'patient_self_report') then '자가평가'
    when afr.source_type::text = 'intake_form' then '인테이크'
    else '전문가 평가'
  end,
  afr.notes,
  jsonb_build_object(
    'form_template_id', afr.form_template_id,
    'source_type', afr.source_type,
    'total_score', afr.total_score,
    'mcid_status', afr.mcid_status,
    'encounter_id', afr.encounter_id
  )
)
from public.assessment_form_responses afr
left join public.encounters enc on enc.id = afr.encounter_id
) projected;
select count(*) as backfilled_activity_session
from (
select public.upsert_person_lifecycle_event(
  act.subject_person_id,
  act.organization_id,
  act.episode_id,
  case act.activity_type
    when 'daily_walk' then 'wellness'
    when 'other' then 'wellness'
    when 'assessment' then 'assessment'
    when 'telehealth' then 'clinical'
    else 'training'
  end,
  case act.activity_type
    when 'clinic_exercise' then 'clinic_exercise'
    when 'gym_training' then 'gym_session'
    when 'competition' then 'competition'
    when 'group_class' then 'group_class'
    when 'daily_walk' then 'daily_walk'
    when 'telehealth' then 'telehealth'
    when 'assessment' then 'activity_assessment'
    else 'home_exercise'
  end,
  case act.activity_type
    when 'clinic_exercise' then 'activity.clinic_exercise'
    when 'gym_training' then 'activity.gym_session'
    when 'competition' then 'activity.competition'
    when 'group_class' then 'activity.group_class'
    when 'daily_walk' then 'activity.daily_walk'
    when 'telehealth' then 'activity.telehealth'
    when 'assessment' then 'activity.assessment'
    when 'other' then 'activity.other'
    else 'activity.home_exercise'
  end,
  act.performed_at,
  case
    when act.source in ('apple_health', 'samsung_health', 'garmin', 'imu', 'camera') then 'device'
    else 'patient'
  end,
  act.created_by,
  'activity_sessions',
  act.id::text,
  case act.activity_type
    when 'home_exercise' then '홈운동'
    when 'clinic_exercise' then '클리닉 운동'
    when 'gym_training' then '헬스장'
    when 'competition' then '대회'
    when 'group_class' then '그룹 수업'
    when 'daily_walk' then '걷기'
    when 'telehealth' then '원격 활동'
    when 'assessment' then '활동 평가'
    else '활동'
  end,
  act.notes,
  jsonb_build_object(
    'activity_type', act.activity_type,
    'source', act.source,
    'status', act.status,
    'duration_seconds', act.duration_seconds,
    'encounter_id', act.encounter_id,
    'care_plan_id', act.care_plan_id,
    'has_timeseries', act.has_timeseries,
    'metrics', act.metrics
  )
)
from public.activity_sessions act
) projected;
select count(*) as backfilled_pghd_observation
from (
select public.upsert_person_lifecycle_event(
  pghd.person_id,
  null,
  pghd.episode_id,
  'pghd',
  'wearable_sync',
  'pghd.sync',
  pghd.effective_datetime,
  case when pghd.data_source = 'manual' then 'patient' else 'device' end,
  pghd.verified_by,
  'pghd_observations',
  pghd.id::text,
  pghd.observation_type,
  case
    when pghd.value_quantity is not null then concat(pghd.value_quantity::text, coalesce(pghd.value_unit, ''))
    else pghd.value_string
  end,
  jsonb_build_object(
    'observation_type', pghd.observation_type,
    'data_source', pghd.data_source,
    'source_device', pghd.source_device,
    'source_app', pghd.source_app,
    'value_quantity', pghd.value_quantity,
    'value_unit', pghd.value_unit,
    'verification_status', pghd.verification_status,
    'data_quality_score', pghd.data_quality_score,
    'encounter_id', pghd.encounter_id,
    'activity_session_id', pghd.activity_session_id
  )
)
from public.pghd_observations pghd
) projected;
select count(*) as backfilled_exercise_prescription_created
from (
select public.upsert_person_lifecycle_event(
  rx.subject_person_id,
  rx.organization_id,
  rx.episode_id,
  'clinical',
  'exercise_prescription',
  'prescription.created',
  rx.created_at,
  'provider',
  rx.created_by,
  'exercise_prescriptions',
  rx.id::text,
  '운동 처방',
  rx.notes,
  jsonb_build_object(
    'exercise_id', rx.exercise_id,
    'encounter_id', rx.encounter_id,
    'status', rx.status,
    'phase', rx.phase,
    'frequency', rx.frequency,
    'frequency_per_week', rx.frequency_per_week,
    'duration_weeks', rx.duration_weeks,
    'rpe_target', rx.rpe_target
  )
)
from public.exercise_prescriptions rx
) projected;
select count(*) as backfilled_exercise_prescription_terminal
from (
select public.upsert_person_lifecycle_event(
  rx.subject_person_id,
  rx.organization_id,
  rx.episode_id,
  'clinical',
  'exercise_prescription',
  case rx.status
    when 'completed' then 'prescription.completed'
    when 'paused' then 'prescription.paused'
    when 'discontinued' then 'prescription.cancelled'
    else 'prescription.updated'
  end,
  rx.updated_at,
  'provider',
  rx.created_by,
  'exercise_prescriptions',
  rx.id::text,
  case rx.status
    when 'completed' then '운동 처방 완료'
    when 'paused' then '운동 처방 일시중지'
    when 'discontinued' then '운동 처방 중단'
    else '운동 처방 변경'
  end,
  rx.notes,
  jsonb_build_object(
    'exercise_id', rx.exercise_id,
    'encounter_id', rx.encounter_id,
    'status', rx.status,
    'phase', rx.phase,
    'frequency', rx.frequency,
    'frequency_per_week', rx.frequency_per_week,
    'duration_weeks', rx.duration_weeks,
    'rpe_target', rx.rpe_target
  )
)
from public.exercise_prescriptions rx
where rx.status in ('completed', 'paused', 'discontinued')
) projected;
select count(*) as backfilled_booking_event
from (
select public.upsert_person_lifecycle_event(
  b.subject_person_id,
  be.organization_id,
  null,
  'scheduling',
  'booking',
  case be.event_type
    when 'BOOKING_CREATED' then 'booking.created'
    when 'CREATED' then 'booking.created'
    when 'CONFIRMED' then 'booking.confirmed'
    when 'REJECTED' then 'booking.rejected'
    when 'COMPLETED' then 'booking.completed'
    when 'CANCELLED' then 'booking.cancelled'
    when 'CANCELLED_BY_PROFESSIONAL' then 'booking.cancelled'
    when 'CANCELLED_BY_PATIENT' then 'booking.cancelled'
    when 'NO_SHOW' then 'booking.no_show'
    when 'RESCHEDULED' then 'booking.rescheduled'
    else 'booking.updated'
  end,
  coalesce(be.created_at, b.scheduled_at),
  case be.actor_type
    when 'patient' then 'patient'
    when 'professional' then 'provider'
    when 'admin' then 'provider'
    else 'system'
  end,
  be.actor_person_id,
  'booking_events',
  be.id::text,
  case
    when be.event_type in ('BOOKING_CREATED', 'CREATED') then '예약 생성'
    when be.event_type = 'CONFIRMED' then '예약 확정'
    when be.event_type = 'REJECTED' then '예약 거절'
    when be.event_type = 'COMPLETED' then '예약 완료'
    when be.event_type in ('CANCELLED', 'CANCELLED_BY_PROFESSIONAL', 'CANCELLED_BY_PATIENT') then '예약 취소'
    when be.event_type = 'NO_SHOW' then '노쇼'
    when be.event_type = 'RESCHEDULED' then '예약 변경'
    else '예약 이벤트'
  end,
  concat_ws(' · ', b.service_type, b.scheduled_at::text),
  jsonb_build_object(
    'booking_id', be.booking_id,
    'booking_event_type', be.event_type,
    'booking_status', b.status,
    'scheduled_at', b.scheduled_at,
    'service_type', b.service_type,
    'payload', be.payload
  )
)
from public.booking_events be
join public.bookings b on b.id = be.booking_id
) projected;
