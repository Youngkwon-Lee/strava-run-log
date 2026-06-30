update public.encounters as e
set flow_mode = coalesce(
  nullif(p.settings -> 'execution_defaults' ->> 'preferredFlowMode', ''),
  nullif(o.settings -> 'execution_defaults' ->> 'preferredFlowMode', ''),
  case
    when p.specialization in ('cardiac', 'oncology', 'pediatric_complex_home') then 'full'
    else case coalesce(
      p.settings ->> 'practice_mode',
      o.settings ->> 'practice_mode'
    )
      when 'hospital_outpatient' then 'full'
      when 'msk_studio' then 'simple'
      when 'home_visit_rehab' then 'full'
      when 'sports_performance' then 'simple'
      when 'wellness_studio' then 'simple'
      else case
        when p.expert_type = 'physiotherapist' then 'full'
        else 'simple'
      end
    end
  end
)
from public.persons as p,
     public.organizations as o
where p.id = e.provider_person_id
  and o.id = e.organization_id
  and e.flow_mode is distinct from coalesce(
    nullif(p.settings -> 'execution_defaults' ->> 'preferredFlowMode', ''),
    nullif(o.settings -> 'execution_defaults' ->> 'preferredFlowMode', ''),
    case
      when p.specialization in ('cardiac', 'oncology', 'pediatric_complex_home') then 'full'
      else case coalesce(
        p.settings ->> 'practice_mode',
        o.settings ->> 'practice_mode'
      )
        when 'hospital_outpatient' then 'full'
        when 'msk_studio' then 'simple'
        when 'home_visit_rehab' then 'full'
        when 'sports_performance' then 'simple'
        when 'wellness_studio' then 'simple'
        else case
          when p.expert_type = 'physiotherapist' then 'full'
          else 'simple'
        end
      end
    end
  );;
