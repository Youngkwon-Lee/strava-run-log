with taxonomy_seed(code, code_display, category, default_value_type, default_unit, notes) as (
  values
    ('ROM_lumbar_extension', 'Lumbar Extension ROM', array['rom']::text[], 'quantity', 'deg', 'Seeded from app observation registry (Wave A2)'),
    ('ROM_lumbar_flexion', 'Lumbar Flexion ROM', array['rom']::text[], 'quantity', 'deg', 'Seeded from app observation registry (Wave A2)'),
    ('ROM_lumbar_rotation', 'Lumbar Rotation ROM', array['rom']::text[], 'quantity', 'deg', 'Seeded from app observation registry (Wave A2)'),
    ('MMT_hip_abduction', 'Hip Abduction MMT', array['mmt']::text[], 'quantity', 'grade', 'Seeded from app observation registry (Wave A2)'),
    ('MMT_hip_extension', 'Hip Extension MMT', array['mmt']::text[], 'quantity', 'grade', 'Seeded from app observation registry (Wave A2)'),
    ('MMT_trunk_flexion', 'Trunk Flexion MMT', array['mmt']::text[], 'quantity', 'grade', 'Seeded from app observation registry (Wave A2)'),
    ('SENS_light_touch', 'Light Touch Sensation', array['sensation']::text[], 'string', null, 'Seeded from app observation registry (Wave A2)'),
    ('SENS_pinprick', 'Pinprick Sensation', array['sensation']::text[], 'string', null, 'Seeded from app observation registry (Wave A2)')
)
insert into public.observation_taxonomy (
  code,
  code_system,
  code_display,
  category,
  default_value_type,
  default_unit,
  data_source,
  is_active,
  notes
)
select
  ts.code,
  'http://physiokorea.com/fhir/observation',
  ts.code_display,
  ts.category,
  ts.default_value_type,
  ts.default_unit,
  'app_registry_seed',
  true,
  ts.notes
from taxonomy_seed ts
where not exists (
  select 1
  from public.observation_taxonomy ot
  where ot.code_system = 'http://physiokorea.com/fhir/observation'
    and ot.code = ts.code
);

create table if not exists public.impairment_observation_links (
  id uuid primary key default gen_random_uuid(),

  impairment_id integer not null
    references public.impairments(id) on delete cascade,
  observation_taxonomy_id uuid not null
    references public.observation_taxonomy(id) on delete cascade,

  role text not null,
  priority_order integer not null default 1,
  notes text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint impairment_observation_links_role_check
    check (role in ('primary', 'secondary', 'quick_screen')),

  constraint impairment_observation_links_priority_check
    check (priority_order >= 1),

  constraint impairment_observation_links_unique
    unique (impairment_id, observation_taxonomy_id)
);

create index if not exists idx_impairment_observation_links_impairment
  on public.impairment_observation_links (impairment_id, role, priority_order);

create index if not exists idx_impairment_observation_links_taxonomy
  on public.impairment_observation_links (observation_taxonomy_id, role, priority_order);

with target_codes(code) as (
  values
    ('MMT_hip_abduction'),
    ('MMT_hip_extension'),
    ('MMT_trunk_flexion'),
    ('ROM_lumbar_extension'),
    ('ROM_lumbar_flexion'),
    ('ROM_lumbar_rotation'),
    ('SENS_light_touch'),
    ('SENS_pinprick')
)
insert into public.impairment_observation_links (
  impairment_id,
  observation_taxonomy_id,
  role,
  priority_order,
  notes
)
select
  i.id as impairment_id,
  ot.id as observation_taxonomy_id,
  case
    when ac.ord = 1 then 'primary'
    else 'secondary'
  end as role,
  ac.ord as priority_order,
  'seeded from impairments.assessment_codes observation-style exact code match' as notes
from public.impairments i
cross join lateral unnest(coalesce(i.assessment_codes, '{}'::text[])) with ordinality as ac(code, ord)
join target_codes tc on tc.code = ac.code
join public.observation_taxonomy ot
  on ot.code_system = 'http://physiokorea.com/fhir/observation'
 and ot.code = ac.code
where i.is_active = true
on conflict (impairment_id, observation_taxonomy_id) do nothing;;
