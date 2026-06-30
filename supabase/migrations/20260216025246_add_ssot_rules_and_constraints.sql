-- 1. care_relationship: primary는 client당 org당 1명만
CREATE UNIQUE INDEX idx_care_rel_one_primary
  ON care_relationship(organization_id, client_person_id)
  WHERE role = 'primary' AND status = 'active';

-- SSOT 규칙을 COMMENT로 명시
COMMENT ON TABLE care_relationship IS 'SSOT for longitudinal provider-client assignment.
- role=primary: 담당 치료사 (org+client당 1명, active 상태)
- role=secondary: 보조 치료사
- role=supervisor: 감독 (read + approve, write 불가)
- role=consultant: 자문 (read only)

SSoT 규칙:
- care_relationship = 담당자 (longitudinal)
- encounters.provider_person_id = 세션 시행자 (per-session performer)
- analytics/매칭: care_relationship 우선, 없으면 encounter fallback';

-- 2. encounters SSOT 규칙
COMMENT ON COLUMN encounters.provider_person_id IS 'Session performer (시행자). 담당자(SSOT)는 care_relationship 참조.';
COMMENT ON COLUMN encounters.care_setting IS 'Delivery mode: hospital/clinic/gym/wellness_center/home/remote/hybrid/outdoor. 장소(location_id)와 별개 - remote+location_id=NULL 허용.';
COMMENT ON COLUMN encounters.location_id IS 'Physical location/branch. care_setting과 독립 - remote면 NULL 가능.';
COMMENT ON COLUMN encounters.rate_plan_id IS 'Catalog price. 실제 청구 SSOT는 invoice_line_items (ledger).';

-- 3. data_sharing_consent SSOT 규칙
COMMENT ON TABLE data_sharing_consent IS 'Cross-org data sharing consent.

안전 규칙:
- consent = READ 권한만 부여 (데이터 복제 금지)
- 복제 필요시 별도 sync_job + audit 추적
- revoke 후 캐시/복제 데이터 즉시 무효화

scope: observations, notes, media, encounters, summary_only';

-- 4. rate_plans / billing SSOT
COMMENT ON TABLE rate_plans IS 'Service pricing catalog (가격표).
- rate_plan = 기본 단가 (catalog)
- invoice_line_items = 실제 거래 기록 (ledger, SSOT)
- 할인/예외/수정은 invoice_line_items에서 처리';

-- 5. data_provenance 규칙
COMMENT ON COLUMN data_provenance.data_rights IS 'Data ownership.
- client_owned: PGHD/self-report, 기본 공유 가능(동의 기반)
- org_owned: clinical data, org 밖 공유는 consent 필요
- shared: cross-org 동의 거친 데이터
- platform_owned: 분석/운영 (비식별/집계만)

필수 provenance 대상: observations, encounter_notes, pghd_observations';;
