alter table public.encounters
add column if not exists flow_mode text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'encounters_flow_mode_check'
  ) then
    alter table public.encounters
    add constraint encounters_flow_mode_check
    check (flow_mode in ('full', 'simple'));
  end if;
end
$$;

update public.encounters as e
set flow_mode = coalesce(
  nullif(p.settings -> 'execution_defaults' ->> 'preferredFlowMode', ''),
  nullif(o.settings -> 'execution_defaults' ->> 'preferredFlowMode', ''),
  case coalesce(
    p.settings ->> 'practice_mode',
    o.settings ->> 'practice_mode'
  )
    when 'hospital_outpatient' then 'full'
    when 'msk_studio' then 'simple'
    when 'home_visit_rehab' then 'simple'
    when 'sports_performance' then 'simple'
    when 'wellness_studio' then 'simple'
    else case
      when p.expert_type = 'physiotherapist' then 'full'
      else 'simple'
    end
  end
)
from public.persons as p,
     public.organizations as o
where p.id = e.provider_person_id
  and o.id = e.organization_id
  and e.flow_mode is null;;
