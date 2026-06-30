-- Backfill provider profiles from existing bookings
-- 목적: bookings.provider_person_id 를 org_provider_profile 과 연결 가능하게 정규화

insert into public.org_provider_profile (
  organization_id,
  person_id,
  provider_type,
  title,
  metadata
)
select
  b.organization_id,
  b.provider_person_id,
  case
    when p.expert_type in (
      'clinician','trainer','pilates_instructor','wellness_coach',
      'occupational_therapist','speech_therapist','psychologist',
      'exercise_specialist','researcher'
    ) then p.expert_type
    else 'clinician'
  end as provider_type,
  nullif(p.specialization, '') as title,
  jsonb_build_object(
    'source', 'backfill_from_bookings',
    'backfilled_at', now()
  ) as metadata
from (
  select distinct organization_id, provider_person_id
  from public.bookings
  where organization_id is not null
    and provider_person_id is not null
) b
join public.persons p on p.id = b.provider_person_id
left join public.org_provider_profile opp
  on opp.organization_id = b.organization_id
 and opp.person_id = b.provider_person_id
where opp.id is null;
