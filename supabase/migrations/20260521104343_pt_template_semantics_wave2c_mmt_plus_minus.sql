update public.assessment_form_templates
set
  items = (
    select jsonb_agg(
      case
        when item ->> 'score_key' in ('mmt_left', 'mmt_right') then
          jsonb_set(
            item,
            '{options}',
            '[
              {"value":"0","label":"0 (Zero)"},
              {"value":"1","label":"1 (Trace)"},
              {"value":"2","label":"2 (Poor)"},
              {"value":"3","label":"3 (Fair)"},
              {"value":"4-","label":"4- (Good Minus)"},
              {"value":"4","label":"4 (Good)"},
              {"value":"4+","label":"4+ (Good Plus)"},
              {"value":"5","label":"5 (Normal)"}
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
