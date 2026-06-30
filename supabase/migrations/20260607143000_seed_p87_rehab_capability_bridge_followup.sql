-- Seed P87 follow-up capability bridges for recently added rehab assessment cards.
-- Purpose:
-- - connect pediatric upper-limb and groin field-test cards into the capability layer
-- - keep the wave small and precise; no new schema, no licensed wording, no new exercise rules

with mapping_seed (
  observation_code,
  capability_code,
  default_unit,
  value_type_hint,
  completion_level,
  rationale
) as (
  values
    (
      'QUEST_total_score',
      'upper_limb_reach_capacity',
      'score',
      'quantity',
      'L1',
      'QUEST total score is a usable pediatric upper-limb reach anchor for reach-demand and task-height reasoning.'
    ),
    (
      'QUEST_total_score',
      'distal_upper_limb_function',
      'score',
      'quantity',
      'L1',
      'QUEST total score is a usable pediatric hand-use proxy for grasp and distal upper-limb follow-up reasoning.'
    ),
    (
      'COPENHAGEN_hold_time_seconds',
      'hip_adduction_strength',
      'seconds',
      'quantity',
      'L1',
      'Copenhagen hold time is a usable groin/adductor strength-endurance anchor for sports follow-up reasoning.'
    )
)
insert into public.movement_capability_observation_mappings (
  observation_code,
  observation_code_system,
  capability_id,
  default_unit,
  value_type_hint,
  metadata,
  status
)
select
  ms.observation_code,
  'http://physiokorea.com/fhir/observation',
  mc.id,
  ms.default_unit,
  ms.value_type_hint,
  jsonb_build_object(
    'seed_wave', 'p87_rehab_capability_bridge_followup',
    'completion_level', ms.completion_level,
    'rationale', ms.rationale
  ),
  'active'
from mapping_seed ms
join public.movement_capabilities mc
  on mc.capability_code = ms.capability_code
 and mc.status = 'active'
on conflict (observation_code, observation_code_system, capability_id) do update
set default_unit = excluded.default_unit,
    value_type_hint = excluded.value_type_hint,
    metadata = public.movement_capability_observation_mappings.metadata || excluded.metadata,
    status = 'active',
    updated_at = now();
