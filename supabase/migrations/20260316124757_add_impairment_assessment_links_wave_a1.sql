create table if not exists public.impairment_assessment_links (
  id uuid primary key default gen_random_uuid(),

  impairment_id integer not null
    references public.impairments(id) on delete cascade,
  assessment_template_id integer not null
    references public.assessment_form_templates(id) on delete cascade,

  role text not null,
  priority_order integer not null default 1,
  notes text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint impairment_assessment_links_role_check
    check (role in ('primary', 'secondary', 'quick_screen')),

  constraint impairment_assessment_links_priority_check
    check (priority_order >= 1),

  constraint impairment_assessment_links_unique
    unique (impairment_id, assessment_template_id)
);

create index if not exists idx_impairment_assessment_links_impairment
  on public.impairment_assessment_links (impairment_id, role, priority_order);

create index if not exists idx_impairment_assessment_links_template
  on public.impairment_assessment_links (assessment_template_id, role, priority_order);

insert into public.impairment_assessment_links (
  impairment_id,
  assessment_template_id,
  role,
  priority_order,
  notes
)
select
  i.id as impairment_id,
  aft.id as assessment_template_id,
  case
    when ac.ord = 1 then 'primary'
    else 'secondary'
  end as role,
  ac.ord as priority_order,
  'seeded from impairments.assessment_codes exact template match' as notes
from public.impairments i
cross join lateral unnest(coalesce(i.assessment_codes, '{}'::text[]))
  with ordinality as ac(code, ord)
join public.assessment_form_templates aft
  on aft.form_code = ac.code
where i.is_active = true
on conflict (impairment_id, assessment_template_id) do nothing;;
