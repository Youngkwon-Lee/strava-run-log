create table if not exists public.movement_pattern_impairment_links (
  id uuid primary key default gen_random_uuid(),

  movement_pattern_id integer not null
    references public.movement_patterns(id) on delete cascade,
  impairment_id integer not null
    references public.impairments(id) on delete cascade,

  relationship_type text not null,
  weight numeric not null default 1.0,
  notes text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint movement_pattern_impairment_links_relationship_check
    check (relationship_type in ('primary_driver', 'secondary_driver', 'associated')),

  constraint movement_pattern_impairment_links_unique
    unique (movement_pattern_id, impairment_id, relationship_type)
);

create index if not exists idx_movement_pattern_impairment_links_pattern
  on public.movement_pattern_impairment_links (movement_pattern_id, relationship_type, weight desc);

create index if not exists idx_movement_pattern_impairment_links_impairment
  on public.movement_pattern_impairment_links (impairment_id, relationship_type, weight desc);

insert into public.movement_pattern_impairment_links (
  movement_pattern_id,
  impairment_id,
  relationship_type,
  weight,
  notes
)
select
  mp.id as movement_pattern_id,
  impairment_id,
  'associated' as relationship_type,
  1.0 as weight,
  'seeded from movement_patterns.related_impairment_ids' as notes
from public.movement_patterns mp
cross join lateral unnest(coalesce(mp.related_impairment_ids, '{}'::integer[])) as impairment_id
where mp.is_active = true
on conflict (movement_pattern_id, impairment_id, relationship_type) do nothing;;
