-- P1 follow-up: add covering index for referral_link_events foreign key.

create index if not exists idx_referral_link_events_visitor_person_id
  on public.referral_link_events (visitor_person_id);;
