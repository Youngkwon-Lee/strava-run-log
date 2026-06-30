-- Phase C: Ankle classifications
INSERT INTO public.clinical_classifications (framework_id, code, body_region, name, name_ko, prevalence_pct, differential_from)
VALUES
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_JOSPT_ANKLE_SPRAIN_2021'), 'ankle_acute_sprain', 'ankle', 'Acute Ankle Sprain (<4 weeks)', '급성 발목 염좌 (<4주)', 15, ARRAY['ankle_mobility_deficit']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_JOSPT_ANKLE_SPRAIN_2021'), 'ankle_mobility_deficit', 'ankle', 'Ankle Mobility Deficit (ROM Loss)', '발목 가동성 제한 (ROM 손실)', 12, ARRAY['ankle_acute_sprain']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_JOSPT_ANKLE_SPRAIN_2021'), 'ankle_cai_instability', 'ankle', 'Chronic Ankle Instability', '만성 발목 불안정성', 18, ARRAY['ankle_mobility_deficit']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_JOSPT_ANKLE_SPRAIN_2021'), 'ankle_syndesmosis', 'ankle', 'High Ankle Sprain (Syndesmosis)', '고위 발목 염좌 (상종아관절)', 8, ARRAY['ankle_cai_instability','ankle_mobility_deficit']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_JOSPT_ANKLE_SPRAIN_2021'), 'achilles_tendinopathy', 'ankle', 'Achilles Tendinopathy', '아킬레스건염', 12, ARRAY['ankle_mobility_deficit']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_JOSPT_ANKLE_SPRAIN_2021'), 'ankle_proprioceptive_deficit', 'ankle', 'Ankle Proprioceptive Deficit', '발목 고유감각 결손', 10, ARRAY['ankle_cai_instability'])
ON CONFLICT(code) DO NOTHING;;
