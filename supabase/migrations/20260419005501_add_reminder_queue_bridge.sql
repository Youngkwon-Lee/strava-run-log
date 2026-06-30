-- Bridge appointment_reminders -> scheduled_reminders -> notification_logs

create or replace function public.enqueue_appointment_reminder()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject text;
  v_message text;
  v_recipient uuid;
begin
  -- recipient is booking subject (patient)
  select b.subject_person_id
    into v_recipient
  from public.bookings b
  where b.id = new.booking_id;

  if v_recipient is null then
    return new;
  end if;

  v_subject := '예약 리마인더';
  v_message := format('예약 시간 안내: %s', to_char(new.reminder_time at time zone 'Asia/Seoul', 'YYYY-MM-DD HH24:MI'));

  insert into public.scheduled_reminders (
    organization_id,
    recipient_person_id,
    recipient_type,
    reminder_type,
    related_entity_type,
    related_entity_id,
    scheduled_for,
    reminder_offset_minutes,
    subject,
    message,
    channels,
    status,
    metadata,
    trigger_type,
    trigger_ref_id
  )
  values (
    new.organization_id,
    v_recipient,
    'patient',
    'appointment',
    'booking',
    new.booking_id,
    new.reminder_time,
    new.reminder_offset_minutes,
    v_subject,
    v_message,
    new.channels,
    'pending',
    jsonb_build_object('source','appointment_reminders','appointment_reminder_id',new.id),
    'appointment_reminder',
    new.id::text
  )
  on conflict do nothing;

  return new;
end;
$$;
drop trigger if exists trg_enqueue_appointment_reminder on public.appointment_reminders;
create trigger trg_enqueue_appointment_reminder
after insert on public.appointment_reminders
for each row execute function public.enqueue_appointment_reminder();
-- Backfill existing appointment reminders into scheduled_reminders
insert into public.scheduled_reminders (
  organization_id,
  recipient_person_id,
  recipient_type,
  reminder_type,
  related_entity_type,
  related_entity_id,
  scheduled_for,
  reminder_offset_minutes,
  subject,
  message,
  channels,
  status,
  metadata,
  trigger_type,
  trigger_ref_id
)
select
  ar.organization_id,
  b.subject_person_id,
  'patient',
  'appointment',
  'booking',
  ar.booking_id,
  ar.reminder_time,
  ar.reminder_offset_minutes,
  '예약 리마인더',
  format('예약 시간 안내: %s', to_char(ar.reminder_time at time zone 'Asia/Seoul', 'YYYY-MM-DD HH24:MI')),
  ar.channels,
  case when ar.status = 'sent' then 'sent' else 'pending' end,
  jsonb_build_object('source','appointment_reminders','appointment_reminder_id',ar.id),
  'appointment_reminder',
  ar.id::text
from public.appointment_reminders ar
join public.bookings b on b.id = ar.booking_id
where b.subject_person_id is not null
on conflict do nothing;
-- Create notification_logs for due scheduled reminders (if absent)
with due as (
  select sr.id, sr.organization_id, sr.recipient_person_id, sr.subject, sr.message, sr.channels, sr.scheduled_for
  from public.scheduled_reminders sr
  where sr.status = 'pending'
    and sr.scheduled_for <= now()
    and not exists (
      select 1
      from public.notification_logs nl
      where nl.trigger_type = 'scheduled_reminder'
        and nl.metadata->>'scheduled_reminder_id' = sr.id::text
    )
)
insert into public.notification_logs (
  recipient_id,
  recipient_type,
  organization_id,
  notification_type,
  subject,
  content,
  status,
  scheduled_at,
  metadata,
  channel,
  message_preview,
  trigger_type
)
select
  d.recipient_person_id,
  'patient',
  d.organization_id,
  case
    when coalesce(d.channels[1], 'in_app') in ('sms','email','push','in_app','kakao') then d.channels[1]
    else 'in_app'
  end,
  d.subject,
  d.message,
  'pending',
  d.scheduled_for,
  jsonb_build_object('source','scheduled_reminders','scheduled_reminder_id',d.id),
  coalesce(d.channels[1], 'in_app'),
  left(d.message, 120),
  'scheduled_reminder'
from due d;
