-- Phase C: Hip classifications
INSERT INTO public.clinical_classifications (framework_id, code, body_region, name, name_ko, prevalence_pct, differential_from)
VALUES
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_BJSM_HIP_FAI_OA_2018'), 'hip_mobility_deficit', 'hip', 'Hip Mobility Deficit', '고관절 가동성 제한', 12, ARRAY['hip_fai_symptomatic']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_BJSM_HIP_FAI_OA_2018'), 'hip_fai_asymptomatic', 'hip', 'FAI (Asymptomatic, Imaging+)', '고관절 충돌 (무증상, 영상+)', 8, ARRAY['hip_fai_symptomatic']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_BJSM_HIP_FAI_OA_2018'), 'hip_fai_symptomatic', 'hip', 'Femoroacetabular Impingement (Symptomatic)', '대퇴골-비구 충돌증후군 (유증상)', 14, ARRAY['hip_mobility_deficit','hip_gtps']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_BJSM_HIP_FAI_OA_2018'), 'hip_gtps', 'hip', 'Greater Trochanteric Pain Syndrome', '대전자 통증증후군', 10, ARRAY['hip_mobility_deficit']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_BJSM_HIP_FAI_OA_2018'), 'hip_oa_mild', 'hip', 'Hip OA (Mild, HHS 55-75)', '고관절 골관절염 (경도, HHS 55-75)', 10, ARRAY['hip_oa_moderate']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_BJSM_HIP_FAI_OA_2018'), 'hip_oa_moderate', 'hip', 'Hip OA (Moderate, HHS 40-55)', '고관절 골관절염 (중등도, HHS 40-55)', 12, ARRAY['hip_oa_mild','hip_oa_advanced']),
  ((SELECT id FROM public.reasoning_frameworks WHERE code = 'T_BJSM_HIP_FAI_OA_2018'), 'hip_oa_advanced', 'hip', 'Hip OA (Advanced, THA Candidate)', '고관절 골관절염 (중증, THA 후보)', 12, ARRAY['hip_oa_moderate'])
ON CONFLICT(code) DO NOTHING;;
