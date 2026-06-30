-- Sync no_show state from encounters to bookings

create or replace function public.sync_booking_no_show_from_encounter()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.booking_id is null then
    return new;
  end if;

  if new.finish_reason = 'no_show'
     and new.status = 'finished'
     and (tg_op = 'INSERT' or old.finish_reason is distinct from new.finish_reason or old.status is distinct from new.status)
  then
    update public.bookings b
       set status = 'no_show',
           updated_at = now()
     where b.id = new.booking_id
       and b.status <> 'no_show'
       and b.status in ('pending','confirmed','checked_in');
  end if;

  return new;
end;
$$;
drop trigger if exists trg_sync_booking_no_show_from_encounter on public.encounters;
create trigger trg_sync_booking_no_show_from_encounter
after insert or update on public.encounters
for each row execute function public.sync_booking_no_show_from_encounter();
-- Backfill safety: existing no_show encounters with booking_id should mark booking as no_show.
update public.bookings b
   set status = 'no_show',
       updated_at = now()
  from public.encounters e
 where e.booking_id = b.id
   and e.status = 'finished'
   and e.finish_reason = 'no_show'
   and b.status in ('pending','confirmed','checked_in');
