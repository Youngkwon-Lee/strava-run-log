-- Add canonical exercise session logs.
-- mobile_exercise_sessions remains the mobile/video capture source; this table is
-- the richer prescription/exercise-level tracking record used for reasoning.

create table if not exists public.exercise_session_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  subject_person_id uuid not null references public.persons(id) on delete cascade,
  exercise_id integer not null references public.exercises(id) on delete cascade,
  exercise_prescription_id uuid references public.exercise_prescriptions(id) on delete set null,
  source_mobile_session_id uuid references public.mobile_exercise_sessions(id) on delete set null,
  encounter_id uuid references public.encounters(id) on delete set null,
  episode_id uuid references public.episodes(id) on delete set null,
  performed_at timestamptz not null default now(),
  completed_at timestamptz,
  completion_status text not null default 'completed',
  adherence_status text not null default 'unknown',
  prescribed_sets integer,
  prescribed_reps integer,
  prescribed_hold_seconds integer,
  prescribed_duration_seconds integer,
  completed_sets integer,
  completed_reps integer,
  completed_hold_seconds integer,
  duration_seconds integer,
  pain_before_nprs smallint,
  pain_after_nprs smallint,
  pain_24h_nprs smallint,
  rpe smallint,
  rpe_scale text not null default '0_10',
  difficulty_feedback text,
  symptom_response text,
  pose_accuracy numeric,
  best_accuracy numeric,
  form_quality_score numeric,
  patient_note text,
  clinician_note text,
  feedback jsonb not null default '{}'::jsonb,
  media_refs jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  recorded_source text not null default 'client_portal',
  recorded_by uuid references public.persons(id) on delete set null,
  record_status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_session_logs_completion_status_check check (
    completion_status = any (array['planned','completed','partial','skipped','stopped','entered_in_error']::text[])
  ),
  constraint exercise_session_logs_adherence_status_check check (
    adherence_status = any (array['completed_as_prescribed','modified','partial','skipped','unknown']::text[])
  ),
  constraint exercise_session_logs_pain_before_check check (pain_before_nprs is null or pain_before_nprs between 0 and 10),
  constraint exercise_session_logs_pain_after_check check (pain_after_nprs is null or pain_after_nprs between 0 and 10),
  constraint exercise_session_logs_pain_24h_check check (pain_24h_nprs is null or pain_24h_nprs between 0 and 10),
  constraint exercise_session_logs_rpe_check check (rpe is null or rpe between 0 and 10),
  constraint exercise_session_logs_rpe_scale_check check (rpe_scale = any (array['0_10','borg_6_20','other']::text[])),
  constraint exercise_session_logs_difficulty_check check (
    difficulty_feedback is null
    or difficulty_feedback = any (array['too_easy','appropriate','too_hard','pain_limited','fatigue_limited','unknown']::text[])
  ),
  constraint exercise_session_logs_symptom_response_check check (
    symptom_response is null
    or symptom_response = any (array['improved','no_change','worse','peripheralized','centralized','unknown']::text[])
  ),
  constraint exercise_session_logs_pose_accuracy_check check (pose_accuracy is null or (pose_accuracy >= 0 and pose_accuracy <= 1)),
  constraint exercise_session_logs_best_accuracy_check check (best_accuracy is null or (best_accuracy >= 0 and best_accuracy <= 1)),
  constraint exercise_session_logs_form_quality_check check (form_quality_score is null or (form_quality_score >= 0 and form_quality_score <= 1)),
  constraint exercise_session_logs_nonnegative_counts_check check (
    (prescribed_sets is null or prescribed_sets >= 0)
    and (prescribed_reps is null or prescribed_reps >= 0)
    and (prescribed_hold_seconds is null or prescribed_hold_seconds >= 0)
    and (prescribed_duration_seconds is null or prescribed_duration_seconds >= 0)
    and (completed_sets is null or completed_sets >= 0)
    and (completed_reps is null or completed_reps >= 0)
    and (completed_hold_seconds is null or completed_hold_seconds >= 0)
    and (duration_seconds is null or duration_seconds >= 0)
  ),
  constraint exercise_session_logs_recorded_source_check check (
    recorded_source = any (array['client_portal','mobile','provider','sensor','api','backfill']::text[])
  ),
  constraint exercise_session_logs_record_status_check check (
    record_status = any (array['active','draft','entered_in_error','deleted']::text[])
  )
);
create index if not exists idx_exercise_session_logs_client_time
  on public.exercise_session_logs (organization_id, subject_person_id, performed_at desc)
  where record_status = 'active';
create index if not exists idx_exercise_session_logs_prescription
  on public.exercise_session_logs (exercise_prescription_id, performed_at desc)
  where exercise_prescription_id is not null and record_status = 'active';
create index if not exists idx_exercise_session_logs_exercise
  on public.exercise_session_logs (exercise_id, performed_at desc)
  where record_status = 'active';
create unique index if not exists uq_exercise_session_logs_mobile_source
  on public.exercise_session_logs (source_mobile_session_id)
  where source_mobile_session_id is not null;
drop trigger if exists exercise_session_logs_set_updated_at
  on public.exercise_session_logs;
create trigger exercise_session_logs_set_updated_at
  before update on public.exercise_session_logs
  for each row execute function public.set_updated_at();
alter table public.exercise_session_logs enable row level security;
drop policy if exists exercise_session_logs_select_member_or_self
  on public.exercise_session_logs;
create policy exercise_session_logs_select_member_or_self
  on public.exercise_session_logs
  for select
  to authenticated
  using (
    subject_person_id = public.get_my_person_id()
    or public.is_org_member(organization_id)
  );
drop policy if exists exercise_session_logs_insert_member_or_self
  on public.exercise_session_logs;
create policy exercise_session_logs_insert_member_or_self
  on public.exercise_session_logs
  for insert
  to authenticated
  with check (
    subject_person_id = public.get_my_person_id()
    or public.is_org_member(organization_id)
  );
drop policy if exists exercise_session_logs_update_member
  on public.exercise_session_logs;
create policy exercise_session_logs_update_member
  on public.exercise_session_logs
  for update
  to authenticated
  using (public.is_org_member(organization_id))
  with check (public.is_org_member(organization_id));
drop policy if exists exercise_session_logs_service_write
  on public.exercise_session_logs;
create policy exercise_session_logs_service_write
  on public.exercise_session_logs
  for all
  to service_role
  using (true)
  with check (true);
with mobile_source as (
  select
    mes.*,
    case
      when mes.feedback is not null
        and (mes.feedback ->> 'prescription_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then (mes.feedback ->> 'prescription_id')::uuid
      else null::uuid
    end as parsed_prescription_id,
    case
      when mes.feedback is not null
        and nullif(mes.feedback ->> 'pain_score', '') is not null
        and (mes.feedback ->> 'pain_score') ~ '^[0-9]+$'
      then (mes.feedback ->> 'pain_score')::smallint
      else null::smallint
    end as parsed_pain_score,
    case
      when mes.feedback is not null
        and nullif(mes.feedback ->> 'rpe', '') is not null
        and (mes.feedback ->> 'rpe') ~ '^[0-9]+$'
      then (mes.feedback ->> 'rpe')::smallint
      else null::smallint
    end as parsed_rpe
  from public.mobile_exercise_sessions mes
  where mes.organization_id is not null
    and mes.subject_person_id is not null
    and mes.exercise_id is not null
)
insert into public.exercise_session_logs (
  organization_id,
  subject_person_id,
  exercise_id,
  exercise_prescription_id,
  source_mobile_session_id,
  encounter_id,
  episode_id,
  performed_at,
  completed_at,
  completion_status,
  adherence_status,
  prescribed_sets,
  prescribed_reps,
  completed_sets,
  completed_reps,
  duration_seconds,
  pain_after_nprs,
  rpe,
  pose_accuracy,
  best_accuracy,
  patient_note,
  feedback,
  metadata,
  recorded_source,
  record_status
)
select
  ms.organization_id,
  ms.subject_person_id,
  ms.exercise_id,
  rx.id,
  ms.id,
  coalesce(ms.encounter_id, rx.encounter_id),
  rx.episode_id,
  coalesce(ms.completed_at, ms.created_at, now()),
  ms.completed_at,
  case
    when ms.status = 'completed' then 'completed'
    when ms.status = 'skipped' then 'skipped'
    when ms.status = 'partial' then 'partial'
    else 'completed'
  end,
  case
    when coalesce(ms.completed_sets, 0) = 0 and coalesce(ms.completed_reps, 0) = 0 then 'unknown'
    when coalesce(ms.target_sets, 0) > 0
      and coalesce(ms.completed_sets, 0) >= coalesce(ms.target_sets, 0)
      and (
        coalesce(ms.target_reps, 0) = 0
        or coalesce(ms.completed_reps, 0) >= coalesce(ms.target_reps, 0)
      )
    then 'completed_as_prescribed'
    when coalesce(ms.completed_sets, 0) > 0 or coalesce(ms.completed_reps, 0) > 0 then 'partial'
    else 'unknown'
  end,
  ms.target_sets,
  ms.target_reps,
  ms.completed_sets,
  ms.completed_reps,
  case when ms.duration_minutes is null then null else ms.duration_minutes * 60 end,
  case when ms.parsed_pain_score between 0 and 10 then ms.parsed_pain_score else null end,
  case when ms.parsed_rpe between 0 and 10 then ms.parsed_rpe else null end,
  ms.pose_accuracy,
  ms.best_accuracy,
  nullif(ms.feedback ->> 'note', ''),
  coalesce(ms.feedback, '{}'::jsonb),
  jsonb_build_object(
    'source_table', 'mobile_exercise_sessions',
    'source_id', ms.id,
    'seed_wave', 'exercise_session_logs_backfill_2026_05_31'
  ),
  'backfill',
  'active'
from mobile_source ms
left join public.exercise_prescriptions rx
  on rx.id = ms.parsed_prescription_id
on conflict (source_mobile_session_id)
  where source_mobile_session_id is not null
do update set
  exercise_prescription_id = excluded.exercise_prescription_id,
  encounter_id = excluded.encounter_id,
  episode_id = excluded.episode_id,
  performed_at = excluded.performed_at,
  completed_at = excluded.completed_at,
  completion_status = excluded.completion_status,
  adherence_status = excluded.adherence_status,
  prescribed_sets = excluded.prescribed_sets,
  prescribed_reps = excluded.prescribed_reps,
  completed_sets = excluded.completed_sets,
  completed_reps = excluded.completed_reps,
  duration_seconds = excluded.duration_seconds,
  pain_after_nprs = excluded.pain_after_nprs,
  rpe = excluded.rpe,
  pose_accuracy = excluded.pose_accuracy,
  best_accuracy = excluded.best_accuracy,
  patient_note = excluded.patient_note,
  feedback = excluded.feedback,
  metadata = public.exercise_session_logs.metadata || excluded.metadata,
  updated_at = now();
