-- Phase C: Add ankle and hip frameworks
INSERT INTO public.reasoning_frameworks (code, name, category, applicable_regions, applicable_domains, evidence_level, description, is_active)
VALUES
  ('T_JOSPT_ANKLE_SPRAIN_2021', 'JOSPT Ankle Sprain Guidelines 2021', 'movement_impairment', ARRAY['ankle'], ARRAY['impairment','activity','participation'], 'A', 'Evidence-based rehabilitation of ankle sprains in athletes', true),
  ('T_BJSM_HIP_FAI_OA_2018', 'BJSM Hip FAI/OA Consensus 2018', 'biomechanical', ARRAY['hip'], ARRAY['impairment','activity','participation'], 'A', 'Management of femoroacetabular impingement and hip osteoarthritis', true)
ON CONFLICT(code) DO NOTHING;;
