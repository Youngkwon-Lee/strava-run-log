
INSERT INTO body_site_registry (code, display, display_korean, snomed_code, laterality_applicable, synonyms)
VALUES
  ('IT_BAND', 'IT Band', '장경인대', '22356005', true, ARRAY['iliotibial band', 'ITB']),
  ('LAT_ELBOW', 'Lateral Elbow', '외측 팔꿈치', '368149001', true, ARRAY['lateral epicondyle', 'tennis elbow area']),
  ('MED_ELBOW', 'Medial Elbow', '내측 팔꿈치', '368148009', true, ARRAY['medial epicondyle', 'golfer elbow area']),
  ('ROTATOR_CUFF', 'Rotator Cuff Region', '회전근개 부위', '361856005', true, ARRAY['rotator cuff', 'RC']),
  ('UPPER_BACK', 'Upper Back', '상배부', '77931009', false, ARRAY['upper thoracic', 'mid back']),
  ('LOWER_BACK', 'Lower Back', '하배부', '37822005', false, ARRAY['lower lumbar', 'lumbosacral']),
  ('TMJ', 'TMJ', '측두하악관절', '53620006', true, ARRAY['temporomandibular joint', 'jaw joint']),
  ('LAT_HIP', 'Lateral Hip', '외측 고관절', '287679003', true, ARRAY['greater trochanter area', 'lateral hip']),
  ('ANT_KNEE', 'Anterior Knee', '전면 무릎', '312745000', true, ARRAY['front knee', 'anterior knee']),
  ('POST_KNEE', 'Posterior Knee', '후면 무릎', '312746004', true, ARRAY['back knee', 'popliteal area']);
;
