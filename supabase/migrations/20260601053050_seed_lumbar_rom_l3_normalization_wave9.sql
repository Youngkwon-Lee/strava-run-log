-- Lumbar ROM L3 normalization wave 9.
-- Purpose: normalize the lumbar ROM family for stronger prescribing by:
-- - canonicalizing degree-unit variants,
-- - preparing future pct_limit inputs,
-- - promoting lumbar ROM capabilities from L2 to MVP L3,
-- - adding direction-aware regression edges.
--
-- Clinical safety note:
-- Degree-based bands below are MVP screening defaults, not diagnostic rules.
-- pct_limit interpretation here treats the source as "percent limitation",
-- so available ROM is derived as:
--   available_deg = reference_range_high * (100 - pct_limit) / 100
-- This assumption matches the current low-back sidecar naming (`*_limit_pct`)
-- and must be reviewed if that source model changes.

with lumbar_mapping_meta as (
  select
    map.id as mapping_id,
    ot.code,
    ot.reference_range_high
  from public.movement_capability_observation_mappings map
  join public.observation_taxonomy ot
    on ot.code = map.observation_code
   and ot.code_system = 'http://physiokorea.com/fhir/observation'
  where map.status = 'active'
    and map.observation_code in (
      'ROM_lumbar_flexion',
      'ROM_lumbar_extension',
      'ROM_lumbar_rotation',
      'ROM_lumbar_lateral_flexion'
    )
)
update public.movement_capability_observation_mappings map
set
  default_unit = 'deg',
  value_type_hint = 'quantity',
  metadata = coalesce(map.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'seed_wave', 'lumbar_rom_l3_normalization_wave9',
      'completion_level', 'L3',
      'plain_status', '처방 판단 가능',
      'normalization', jsonb_build_object(
        'canonical_unit', 'deg',
        'accepted_source_units', jsonb_build_array('deg', 'degree', 'degrees', 'pct_limit'),
        'pct_limit_formula', 'available_deg = reference_range_high * (100 - pct_limit) / 100',
        'reference_range_high', lumbar_mapping_meta.reference_range_high
      )
    ),
  updated_at = now()
from lumbar_mapping_meta
where map.id = lumbar_mapping_meta.mapping_id;
update public.observation_taxonomy ot
set
  interpretation_guide = coalesce(ot.interpretation_guide, '{}'::jsonb)
    || jsonb_build_object(
      'seed_wave', 'lumbar_rom_l3_normalization_wave9',
      'plain_status', '처방 판단 가능',
      'normalization', jsonb_build_object(
        'canonical_unit', 'deg',
        'accepted_source_units', jsonb_build_array('deg', 'degree', 'degrees', 'pct_limit'),
        'pct_limit_formula', 'available_deg = reference_range_high * (100 - pct_limit) / 100'
      )
    ),
  updated_at = now()
where ot.code in (
  'ROM_lumbar_flexion',
  'ROM_lumbar_extension',
  'ROM_lumbar_rotation',
  'ROM_lumbar_lateral_flexion'
)
  and ot.code_system = 'http://physiokorea.com/fhir/observation';
create or replace function private.project_observation_to_patient_capability(p_observation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_upserted_count integer := 0;
begin
  with source_observation as (
    select obs.*
    from public.observations obs
    where obs.id = p_observation_id
  ),
  candidate_projection as (
    select
      obs.organization_id,
      obs.subject_person_id,
      obs.encounter_id,
      obs.id as source_observation_id,
      mapping.capability_id,
      case
        when raw_values.raw_numeric_value is not null then 'quantity'
        when obs.value_boolean is not null then 'boolean'
        when obs.value_json is not null then 'json'
        else 'string'
      end as value_type,
      case
        when obs.code in (
          'ROM_lumbar_flexion',
          'ROM_lumbar_extension',
          'ROM_lumbar_rotation',
          'ROM_lumbar_lateral_flexion'
        )
        and lower(coalesce(obs.value_unit, '')) = 'pct_limit'
        and raw_values.raw_numeric_value is not null
        and ot.reference_range_high is not null
          then round(
            ot.reference_range_high
            * greatest(0::numeric, least(100::numeric, 100::numeric - raw_values.raw_numeric_value))
            / 100::numeric,
            2
          )
        else raw_values.raw_numeric_value
      end as value_quantity,
      case
        when obs.code in (
          'ROM_lumbar_flexion',
          'ROM_lumbar_extension',
          'ROM_lumbar_rotation',
          'ROM_lumbar_lateral_flexion'
        )
        and (
          obs.value_unit is null
          or lower(obs.value_unit) in ('deg', 'degree', 'degrees', 'pct_limit')
        )
          then 'deg'
        else coalesce(obs.value_unit, mapping.default_unit, mc.default_unit)
      end as value_unit,
      obs.value_boolean,
      obs.value_string,
      obs.value_json,
      obs.effective_datetime,
      obs.created_by,
      obs.code,
      obs.code_system,
      obs.laterality,
      obs.value_unit as source_value_unit,
      raw_values.raw_numeric_value,
      case
        when obs.code in (
          'ROM_lumbar_flexion',
          'ROM_lumbar_extension',
          'ROM_lumbar_rotation',
          'ROM_lumbar_lateral_flexion'
        )
        and lower(coalesce(obs.value_unit, '')) = 'pct_limit'
        and raw_values.raw_numeric_value is not null
        and ot.reference_range_high is not null
          then 'lumbar_pct_limit_to_deg'
        when obs.code in (
          'ROM_lumbar_flexion',
          'ROM_lumbar_extension',
          'ROM_lumbar_rotation',
          'ROM_lumbar_lateral_flexion'
        )
        and (
          obs.value_unit is null
          or lower(obs.value_unit) in ('degree', 'degrees')
        )
          then 'canonicalize_degree_unit'
        else null
      end as normalization_strategy,
      ot.reference_range_high as normalization_reference_high,
      case
        when obs.code in (
          'ROM_lumbar_flexion',
          'ROM_lumbar_extension',
          'ROM_lumbar_rotation',
          'ROM_lumbar_lateral_flexion'
        )
        and lower(coalesce(obs.value_unit, '')) = 'pct_limit'
        and raw_values.raw_numeric_value is not null
        and ot.reference_range_high is not null
          then 'Converted lumbar percent limitation to available ROM degrees.'
        when obs.code in (
          'ROM_lumbar_flexion',
          'ROM_lumbar_extension',
          'ROM_lumbar_rotation',
          'ROM_lumbar_lateral_flexion'
        )
        and (
          obs.value_unit is null
          or lower(obs.value_unit) in ('degree', 'degrees')
        )
          then 'Canonicalized lumbar degree-unit variant to deg.'
        else null
      end as normalization_note
    from source_observation obs
    join public.movement_capability_observation_mappings mapping
      on mapping.observation_code = obs.code
     and mapping.status = 'active'
     and (
       mapping.observation_code_system = ''
       or mapping.observation_code_system = coalesce(obs.code_system, '')
     )
    join public.movement_capabilities mc
      on mc.id = mapping.capability_id
     and mc.status = 'active'
    left join public.observation_taxonomy ot
      on ot.code = obs.code
     and ot.code_system = 'http://physiokorea.com/fhir/observation'
    cross join lateral (
      select coalesce(
        obs.value_quantity,
        obs.value_integer::numeric,
        case
          when obs.value_json ->> 'numeric_equivalent' ~ '^-?[0-9]+(\.[0-9]+)?$'
            then (obs.value_json ->> 'numeric_equivalent')::numeric
          else null
        end
      ) as raw_numeric_value
    ) raw_values
    where obs.status <> all (array['entered-in-error'::text, 'cancelled'::text])
  ),
  stale_projection as (
    update public.patient_capability_observations pco
    set
      status = 'deprecated',
      updated_at = now(),
      metadata = pco.metadata || jsonb_build_object(
        'deprecated_reason', 'source_observation_no_longer_projects',
        'deprecated_at', now()
      )
    where pco.source_observation_id = p_observation_id
      and pco.status = 'active'
      and not exists (
        select 1
        from candidate_projection candidate
        where candidate.capability_id = pco.capability_id
          and (
            candidate.value_quantity is not null
            or candidate.value_boolean is not null
            or candidate.value_string is not null
            or candidate.value_json is not null
          )
      )
    returning 1
  ),
  upserted_projection as (
    insert into public.patient_capability_observations (
      organization_id,
      subject_person_id,
      encounter_id,
      source_observation_id,
      capability_id,
      value_type,
      value_quantity,
      value_unit,
      value_boolean,
      value_string,
      value_json,
      interpretation,
      confidence,
      source_type,
      effective_datetime,
      metadata,
      status,
      created_by
    )
    select
      candidate.organization_id,
      candidate.subject_person_id,
      candidate.encounter_id,
      candidate.source_observation_id,
      candidate.capability_id,
      candidate.value_type,
      candidate.value_quantity,
      candidate.value_unit,
      candidate.value_boolean,
      candidate.value_string,
      candidate.value_json,
      'unknown',
      1,
      'observation_projection',
      candidate.effective_datetime,
      jsonb_strip_nulls(jsonb_build_object(
        'source_observation_code', candidate.code,
        'source_observation_code_system', candidate.code_system,
        'laterality', candidate.laterality,
        'source_value_unit', candidate.source_value_unit,
        'raw_numeric_value', candidate.raw_numeric_value,
        'normalization_strategy', candidate.normalization_strategy,
        'normalization_reference_high', candidate.normalization_reference_high,
        'normalization_note', candidate.normalization_note,
        'projection_wave', 'lumbar_rom_l3_normalization_wave9'
      )),
      'active',
      candidate.created_by
    from candidate_projection candidate
    where candidate.value_quantity is not null
       or candidate.value_boolean is not null
       or candidate.value_string is not null
       or candidate.value_json is not null
    on conflict (source_observation_id, capability_id)
      where source_observation_id is not null and status = 'active'
    do update set
      organization_id = excluded.organization_id,
      subject_person_id = excluded.subject_person_id,
      encounter_id = excluded.encounter_id,
      value_type = excluded.value_type,
      value_quantity = excluded.value_quantity,
      value_unit = excluded.value_unit,
      value_boolean = excluded.value_boolean,
      value_string = excluded.value_string,
      value_json = excluded.value_json,
      interpretation = excluded.interpretation,
      confidence = excluded.confidence,
      source_type = excluded.source_type,
      effective_datetime = excluded.effective_datetime,
      metadata = public.patient_capability_observations.metadata || excluded.metadata,
      status = 'active',
      created_by = excluded.created_by,
      updated_at = now()
    returning 1
  )
  select count(*) into v_upserted_count
  from upserted_projection;

  return v_upserted_count;
end;
$$;
revoke all on function private.project_observation_to_patient_capability(uuid)
  from public, anon, authenticated;
with capability_l3_seed as (
  select * from (values
    (
      'lumbar_flexion_mobility',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('lumbar_rom_manual', 'low_back_sidecar_pct_limit'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 40, 'unit', 'deg', 'or_pct_limit_max', 25),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 28, 'and_operator', '<', 'and_value', 40, 'unit', 'deg', 'or_pct_limit_range', '26-50'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 28, 'unit', 'deg', 'or_pct_limit_min', 51)
        ),
        'symptom_response_codes', jsonb_build_array('Pain_repeated_flexion_response'),
        'symptom_response_rule', 'If repeated flexion aggravates symptoms, downgrade one band or use flexion-light regressions even when ROM alone looks ready.',
        'default_regression', 'Prefer cat-cow, reduced-range mobility, unloaded trunk flexion, or symptom-guided short-arc work before deeper loaded flexion patterns.',
        'laterality_required', false,
        'review_note', 'Uses 55deg reference and current low-back sidecar limit_pct naming. Review if source semantics change.'
      )
    ),
    (
      'lumbar_extension_mobility',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('lumbar_rom_manual', 'low_back_sidecar_pct_limit'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 19, 'unit', 'deg', 'or_pct_limit_max', 25),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 13, 'and_operator', '<', 'and_value', 19, 'unit', 'deg', 'or_pct_limit_range', '26-50'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 13, 'unit', 'deg', 'or_pct_limit_min', 51)
        ),
        'symptom_response_codes', jsonb_build_array('Pain_repeated_extension_response'),
        'symptom_response_rule', 'If repeated extension aggravates symptoms, downgrade one band or use extension-light regressions even when ROM alone looks ready.',
        'default_regression', 'Prefer cat-cow, neutral-spine control, reduced-range extension, or unloaded mobility before loaded back extension work.',
        'laterality_required', false,
        'review_note', 'Uses 25deg reference and current low-back sidecar limit_pct naming. Review if source semantics change.'
      )
    ),
    (
      'lumbar_rotation_mobility',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('lumbar_rom_manual', 'low_back_sidecar_pct_limit'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 23, 'unit', 'deg', 'or_pct_limit_max', 25),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 15, 'and_operator', '<', 'and_value', 23, 'unit', 'deg', 'or_pct_limit_range', '26-50'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 15, 'unit', 'deg', 'or_pct_limit_min', 51)
        ),
        'symptom_response_codes', jsonb_build_array('Pain_repeated_flexion_response', 'Pain_repeated_extension_response'),
        'symptom_response_rule', 'If repeated flexion or extension clearly aggravates symptoms, use slower, smaller-range anti-rotation or rotation-light regressions.',
        'default_regression', 'Prefer torso rotation without load, smaller range, or open-book style thoracolumbar rotation before resisted rotation patterns.',
        'laterality_required', false,
        'review_note', 'Uses 30deg reference and current low-back sidecar limit_pct naming. Review if source semantics change.'
      )
    ),
    (
      'lumbar_lateral_flexion_mobility',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('lumbar_rom_manual', 'low_back_sidecar_pct_limit'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 19, 'unit', 'deg', 'or_pct_limit_max', 25),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 13, 'and_operator', '<', 'and_value', 19, 'unit', 'deg', 'or_pct_limit_range', '26-50'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 13, 'unit', 'deg', 'or_pct_limit_min', 51)
        ),
        'symptom_response_codes', jsonb_build_array('Pain_repeated_flexion_response', 'Pain_repeated_extension_response'),
        'symptom_response_rule', 'If side bending provokes or repeated directional loading flares symptoms, downgrade one band and keep loading shorter and lighter.',
        'default_regression', 'Prefer lighter dumbbell side bend, reduced range, or supported lateral mobility before heavier side-bend loading.',
        'laterality_required', true,
        'review_note', 'Uses 25deg reference and current low-back sidecar limit_pct naming. Review if source semantics change.'
      )
    )
  ) as seed(capability_code, l3_rules)
)
update public.movement_capabilities mc
set
  properties = coalesce(mc.properties, '{}'::jsonb)
    || jsonb_build_object(
      'mvp_completion_level', 'L3',
      'plain_status', '처방 판단 가능',
      'l3_rules', capability_l3_seed.l3_rules,
      'seed_wave', 'lumbar_rom_l3_normalization_wave9'
    ),
  updated_at = now()
from capability_l3_seed
where mc.capability_code = capability_l3_seed.capability_code;
with guide_seed as (
  select * from (values
    (
      'ROM_lumbar_flexion',
      28::numeric,
      55::numeric,
      'MVP screen: >=40deg or limit<=25% ready, 28-39deg or limit 26-50% caution, <28deg or limit>50% regress. Repeated flexion aggravation downgrades one band.',
      jsonb_build_object(
        'seed_wave', 'lumbar_rom_l3_normalization_wave9',
        'plain_status', '처방 판단 가능',
        'capability_code', 'lumbar_flexion_mobility',
        'direction', 'higher_is_better_after_pct_limit_normalization',
        'decision_bands', jsonb_build_array('ready: >=40deg or limit<=25%', 'caution: 28-39deg or limit 26-50%', 'regress: <28deg or limit>50%'),
        'symptom_response_code', 'Pain_repeated_flexion_response'
      )
    ),
    (
      'ROM_lumbar_extension',
      13::numeric,
      25::numeric,
      'MVP screen: >=19deg or limit<=25% ready, 13-18deg or limit 26-50% caution, <13deg or limit>50% regress. Repeated extension aggravation downgrades one band.',
      jsonb_build_object(
        'seed_wave', 'lumbar_rom_l3_normalization_wave9',
        'plain_status', '처방 판단 가능',
        'capability_code', 'lumbar_extension_mobility',
        'direction', 'higher_is_better_after_pct_limit_normalization',
        'decision_bands', jsonb_build_array('ready: >=19deg or limit<=25%', 'caution: 13-18deg or limit 26-50%', 'regress: <13deg or limit>50%'),
        'symptom_response_code', 'Pain_repeated_extension_response'
      )
    ),
    (
      'ROM_lumbar_rotation',
      15::numeric,
      30::numeric,
      'MVP screen: >=23deg or limit<=25% ready, 15-22deg or limit 26-50% caution, <15deg or limit>50% regress. Use symptom response to keep rotation conservative when irritated.',
      jsonb_build_object(
        'seed_wave', 'lumbar_rom_l3_normalization_wave9',
        'plain_status', '처방 판단 가능',
        'capability_code', 'lumbar_rotation_mobility',
        'direction', 'higher_is_better_after_pct_limit_normalization',
        'decision_bands', jsonb_build_array('ready: >=23deg or limit<=25%', 'caution: 15-22deg or limit 26-50%', 'regress: <15deg or limit>50%')
      )
    ),
    (
      'ROM_lumbar_lateral_flexion',
      13::numeric,
      25::numeric,
      'MVP screen: >=19deg or limit<=25% ready, 13-18deg or limit 26-50% caution, <13deg or limit>50% regress. Side-specific symptoms should keep loading conservative.',
      jsonb_build_object(
        'seed_wave', 'lumbar_rom_l3_normalization_wave9',
        'plain_status', '처방 판단 가능',
        'capability_code', 'lumbar_lateral_flexion_mobility',
        'direction', 'higher_is_better_after_pct_limit_normalization',
        'laterality_required', true,
        'decision_bands', jsonb_build_array('ready: >=19deg or limit<=25%', 'caution: 13-18deg or limit 26-50%', 'regress: <13deg or limit>50%')
      )
    )
  ) as seed(code, reference_range_low, reference_range_high, reference_range_text, interpretation_guide)
)
update public.observation_taxonomy ot
set
  reference_range_low = guide_seed.reference_range_low,
  reference_range_high = guide_seed.reference_range_high,
  reference_range_text = guide_seed.reference_range_text,
  interpretation_guide = coalesce(ot.interpretation_guide, '{}'::jsonb) || guide_seed.interpretation_guide,
  updated_at = now()
from guide_seed
where ot.code = guide_seed.code
  and ot.code_system = 'http://physiokorea.com/fhir/observation';
update public.observations
set
  value_unit = 'deg',
  updated_at = now()
where code in (
  'ROM_lumbar_flexion',
  'ROM_lumbar_extension',
  'ROM_lumbar_rotation',
  'ROM_lumbar_lateral_flexion'
)
  and value_quantity is not null
  and (
    value_unit is null
    or lower(value_unit) in ('degree', 'degrees')
  );
with progression_seed as (
  select * from (values
    (
      'edb_Hyperextensions_Back_Extensions',
      'pk_cat_cow',
      'regression',
      'range',
      'lumbar_extension_mobility',
      'If lumbar extension mobility or symptom response is limited, regress loaded back extension to cat-cow range work first.'
    ),
    (
      'edb_Pallof_Press_With_Rotation',
      'edb_Torso_Rotation',
      'regression',
      'complexity',
      'lumbar_rotation_mobility',
      'If resisted lumbar rotation is not ready, regress to unloaded torso rotation before anti-rotation with turn.'
    ),
    (
      'edb_Barbell_Side_Bend',
      'edb_Dumbbell_Side_Bend',
      'regression',
      'load',
      'lumbar_lateral_flexion_mobility',
      'If lumbar lateral flexion mobility is limited, regress loaded barbell side bend to lighter dumbbell side bend.'
    )
  ) as seed(
    from_exercise_code,
    to_exercise_code,
    relation_type,
    progression_axis,
    gate_capability_code,
    rationale
  )
)
insert into public.exercise_progressions (
  from_exercise_id,
  to_exercise_id,
  relation_type,
  progression_axis,
  gate_capability_id,
  rationale,
  metadata,
  status
)
select
  ef.id,
  et.id,
  progression_seed.relation_type,
  progression_seed.progression_axis,
  mc.id,
  progression_seed.rationale,
  jsonb_build_object(
    'seed_wave', 'lumbar_rom_l3_normalization_wave9',
    'plain_rule', '쉬운 버전 규칙',
    'mvp_completion_level', 'L3'
  ),
  'active'
from progression_seed
join public.exercises ef
  on ef.exercise_code = progression_seed.from_exercise_code
join public.exercises et
  on et.exercise_code = progression_seed.to_exercise_code
left join public.movement_capabilities mc
  on mc.capability_code = progression_seed.gate_capability_code
on conflict (from_exercise_id, to_exercise_id, relation_type)
  where status = 'active'
do update set
  progression_axis = excluded.progression_axis,
  gate_capability_id = excluded.gate_capability_id,
  rationale = excluded.rationale,
  metadata = public.exercise_progressions.metadata || excluded.metadata,
  updated_at = now();
select coalesce(sum(private.project_observation_to_patient_capability(observations.id)), 0)
from public.observations
where observations.status <> all (array['entered-in-error'::text, 'cancelled'::text])
  and observations.code in (
    'ROM_lumbar_flexion',
    'ROM_lumbar_extension',
    'ROM_lumbar_rotation',
    'ROM_lumbar_lateral_flexion'
  )
  and exists (
    select 1
    from public.movement_capability_observation_mappings mapping
    where mapping.observation_code = observations.code
      and mapping.status = 'active'
      and (
        mapping.observation_code_system = ''
        or mapping.observation_code_system = coalesce(observations.code_system, '')
      )
  );
