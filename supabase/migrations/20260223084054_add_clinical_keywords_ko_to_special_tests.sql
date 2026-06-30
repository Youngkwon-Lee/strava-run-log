
ALTER TABLE special_tests ADD COLUMN IF NOT EXISTS clinical_keywords_ko text;

-- 요추/하지 방사통 관련
UPDATE special_tests SET clinical_keywords_ko = '요추 신경근증 하지 방사통 좌골신경 L4 L5 S1 추간판 탈출 디스크 요통 신경 압박' WHERE name ILIKE '%straight leg raise%' OR korean_name ILIKE '%하지 직거상%';
UPDATE special_tests SET clinical_keywords_ko = '요추 신경근증 하지 방사통 좌골신경 반대측 교차 L4 L5 S1 추간판 탈출 요통' WHERE name ILIKE '%crossed%straight leg%' OR korean_name ILIKE '%교차 하지 직거상%';
UPDATE special_tests SET clinical_keywords_ko = '요추 신경근증 하지 방사통 좌골신경 건측 L4 L5 S1 추간판 탈출 요통' WHERE name ILIKE '%contralateral%' OR korean_name ILIKE '%건측 하지 직거상%';
UPDATE special_tests SET clinical_keywords_ko = '요추 신경 긴장 하지 방사통 신경근증 요통 허리 좌골신경 전체 신경 긴장 검사' WHERE name ILIKE '%slump%' OR korean_name ILIKE '%슬럼프%';
UPDATE special_tests SET clinical_keywords_ko = 'L2 L3 L4 대퇴신경 하지 통증 요추 상부 신경근증 허리 앞 허벅지 통증' WHERE name ILIKE '%femoral nerve%' OR korean_name ILIKE '%대퇴신경 신장%';
UPDATE special_tests SET clinical_keywords_ko = '요추 능동 하지 직거상 신경근증 하지 방사통 요통 허리 불안정' WHERE name ILIKE '%active straight leg%' OR korean_name ILIKE '%능동적 하지 직거상%';
UPDATE special_tests SET clinical_keywords_ko = '하지 직거상 90도 신경근증 요추 햄스트링 구분 방사통 허리' WHERE name ILIKE '%90-90%' OR korean_name ILIKE '%90-90%';

-- 천장관절 관련
UPDATE special_tests SET clinical_keywords_ko = '천장관절 골반 통증 요통 요천추 SI joint 골반 하부 요통' WHERE name ILIKE '%FABER%' OR korean_name ILIKE '%FABER%';
UPDATE special_tests SET clinical_keywords_ko = '천장관절 골반 통증 비구 충돌 고관절 요통 SI joint 골반' WHERE name ILIKE '%FADIR%' OR korean_name ILIKE '%FADIR%';
UPDATE special_tests SET clinical_keywords_ko = '천장관절 골반 통증 SI 관절 요통 하부 요통 겐슬렌' WHERE name ILIKE '%gaenslen%' OR korean_name ILIKE '%겐슬렌%';

-- 무릎 관련
UPDATE special_tests SET clinical_keywords_ko = '전방십자인대 ACL 무릎 불안정 무릎 통증 인대 손상 라크만' WHERE name ILIKE '%lachman%' OR korean_name ILIKE '%라크만%';
UPDATE special_tests SET clinical_keywords_ko = '반월상연골판 무릎 통증 내측 외측 연골판 손상 맥머레이' WHERE name ILIKE '%mcmurray%' OR korean_name ILIKE '%맥머레이%';
UPDATE special_tests SET clinical_keywords_ko = '반월상연골판 무릎 관절선 압통 무릎 통증 내측 외측' WHERE name ILIKE '%joint line tenderness%' OR korean_name ILIKE '%관절선 압통%';

-- 어깨 관련
UPDATE special_tests SET clinical_keywords_ko = '어깨 충돌 증후군 회전근개 어깨 통증 상부 어깨 니어' WHERE name ILIKE '%neer%' OR korean_name ILIKE '%니어%';
UPDATE special_tests SET clinical_keywords_ko = '회전근개 파열 어깨 통증 극상근 드롭 암' WHERE name ILIKE '%drop arm%' OR korean_name ILIKE '%드롭 암%';

-- 경추 관련
UPDATE special_tests SET clinical_keywords_ko = '경추 신경근증 목 통증 상지 방사통 목 디스크 경추 압박' WHERE name ILIKE '%spurling%' OR korean_name ILIKE '%경추 압박%';
UPDATE special_tests SET clinical_keywords_ko = '경추 신경근증 목 방사통 경추 견인 감압 목 디스크' WHERE name ILIKE '%cervical distraction%' OR korean_name ILIKE '%경추 견인%';
;
