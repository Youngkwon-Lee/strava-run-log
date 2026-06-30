update public.assessment_form_templates
set
  items = (
    select jsonb_agg(
      case
        when item ->> 'score_key' = 'mmt_muscle' then
          item
          || jsonb_build_object(
            'answer_type', 'select',
            'options', '[
              {"value":"MMT_shoulder_flexion","label":"어깨 굴곡 (Shoulder Flexion)"},
              {"value":"MMT_shoulder_abduction","label":"어깨 외전 (Shoulder Abduction)"},
              {"value":"MMT_shoulder_external_rotation","label":"어깨 외회전 (Shoulder External Rotation)"},
              {"value":"MMT_shoulder_internal_rotation","label":"어깨 내회전 (Shoulder Internal Rotation)"},
              {"value":"MMT_elbow_flexion","label":"팔꿈치 굴곡 (Elbow Flexion)"},
              {"value":"MMT_elbow_extension","label":"팔꿈치 신전 (Elbow Extension)"},
              {"value":"MMT_hip_flexion","label":"고관절 굴곡 (Hip Flexion)"},
              {"value":"MMT_hip_extension","label":"고관절 신전 (Hip Extension)"},
              {"value":"MMT_hip_abduction","label":"고관절 외전 (Hip Abduction)"},
              {"value":"MMT_knee_flexion","label":"무릎 굴곡 (Knee Flexion)"},
              {"value":"MMT_knee_extension","label":"무릎 신전 (Knee Extension)"},
              {"value":"MMT_ankle_dorsiflexion","label":"발목 배굴 (Ankle Dorsiflexion)"},
              {"value":"MMT_ankle_plantarflexion","label":"발목 저굴 (Ankle Plantarflexion)"}
            ]'::jsonb
          )
        else item
      end
      order by coalesce((item ->> 'question_number')::int, 9999)
    )
    from jsonb_array_elements(coalesce(public.assessment_form_templates.items, '[]'::jsonb)) item
  ),
  updated_at = now()
where form_code = 'MMT';
update public.assessment_template_item_semantic_links
set
  metadata = coalesce(metadata, '{}'::jsonb)
    || jsonb_build_object(
      'wave', 'pt_template_semantics_wave2d',
      'input_style', 'curated_select',
      'allowed_targets', jsonb_build_array(
        'MMT_shoulder_flexion',
        'MMT_shoulder_abduction',
        'MMT_shoulder_external_rotation',
        'MMT_shoulder_internal_rotation',
        'MMT_elbow_flexion',
        'MMT_elbow_extension',
        'MMT_hip_flexion',
        'MMT_hip_extension',
        'MMT_hip_abduction',
        'MMT_knee_flexion',
        'MMT_knee_extension',
        'MMT_ankle_dorsiflexion',
        'MMT_ankle_plantarflexion'
      )
    ),
  notes = 'Wave 2D constrains generic MMT target-muscle capture to curated canonical MMT_* codes.',
  updated_at = now()
where observation_code = 'mmt_target_muscle'
  and score_key = 'mmt_muscle'
  and form_template_id in (
    select id
    from public.assessment_form_templates
    where form_code = 'MMT'
  );
