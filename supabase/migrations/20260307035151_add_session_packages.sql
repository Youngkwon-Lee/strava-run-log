
-- ============================================================
-- service_packages: 패키지 카탈로그 (조직별 요금표)
-- ============================================================
CREATE TABLE service_packages (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id      uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  service_type         text NOT NULL,
  total_sessions       integer NOT NULL CHECK (total_sessions > 0),
  price                numeric(12,2) NOT NULL CHECK (price >= 0),
  currency             text NOT NULL DEFAULT 'KRW',
  validity_days        integer NOT NULL DEFAULT 90 CHECK (validity_days > 0),
  is_active            boolean NOT NULL DEFAULT true,
  description          text,
  created_at           timestamptz DEFAULT now(),
  updated_at           timestamptz DEFAULT now()
);

-- ============================================================
-- client_session_packages: 고객이 구매한 패키지 (잔여 세션 추적)
-- ============================================================
CREATE TABLE client_session_packages (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id      uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  client_person_id     uuid NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  package_id           uuid NOT NULL REFERENCES service_packages(id),
  -- 구매 시점 스냅샷 (카탈로그 변경에 영향받지 않음)
  package_name         text NOT NULL,
  service_type         text NOT NULL,
  sessions_total       integer NOT NULL CHECK (sessions_total > 0),
  sessions_used        integer NOT NULL DEFAULT 0 CHECK (sessions_used >= 0),
  price_paid           numeric(12,2) NOT NULL,
  currency             text NOT NULL DEFAULT 'KRW',
  purchased_at         timestamptz NOT NULL DEFAULT now(),
  expires_at           timestamptz NOT NULL,
  status               text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','exhausted','expired','cancelled')),
  invoice_id           uuid REFERENCES invoices(id),
  notes                text,
  created_at           timestamptz DEFAULT now(),
  updated_at           timestamptz DEFAULT now(),
  CONSTRAINT chk_sessions_used_lte_total CHECK (sessions_used <= sessions_total)
);

-- sessions_remaining 편의 컬럼
ALTER TABLE client_session_packages
  ADD COLUMN sessions_remaining integer GENERATED ALWAYS AS (sessions_total - sessions_used) STORED;

-- bookings에 패키지 연결 컬럼 추가
ALTER TABLE bookings
  ADD COLUMN client_package_id uuid REFERENCES client_session_packages(id);

-- ============================================================
-- 트리거: booking completed → 세션 자동 차감 + 상태 전이
-- ============================================================
CREATE OR REPLACE FUNCTION deduct_package_session()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- completed 전환이고 패키지가 연결된 경우만 처리
  IF NEW.status = 'completed'
     AND OLD.status <> 'completed'
     AND NEW.client_package_id IS NOT NULL
  THEN
    UPDATE client_session_packages
    SET
      sessions_used = sessions_used + 1,
      status = CASE
                 WHEN sessions_used + 1 >= sessions_total THEN 'exhausted'
                 ELSE status
               END,
      updated_at = now()
    WHERE id = NEW.client_package_id
      AND status = 'active';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_booking_completed_deduct_session
  AFTER UPDATE ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION deduct_package_session();

-- ============================================================
-- 트리거: updated_at 자동 갱신
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_service_packages_updated_at
  BEFORE UPDATE ON service_packages
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_client_session_packages_updated_at
  BEFORE UPDATE ON client_session_packages
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- RLS
-- ============================================================
ALTER TABLE service_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_session_packages ENABLE ROW LEVEL SECURITY;

-- service_packages: 같은 org 멤버 조회, admin/owner만 수정
CREATE POLICY "sp_select" ON service_packages
  FOR SELECT USING (is_org_member(organization_id));

CREATE POLICY "sp_insert" ON service_packages
  FOR INSERT WITH CHECK (is_org_admin(organization_id));

CREATE POLICY "sp_update" ON service_packages
  FOR UPDATE USING (is_org_admin(organization_id));

CREATE POLICY "sp_delete" ON service_packages
  FOR DELETE USING (is_org_admin(organization_id));

-- client_session_packages: 같은 org 멤버 조회, admin/owner만 수정
CREATE POLICY "csp_select" ON client_session_packages
  FOR SELECT USING (is_org_member(organization_id));

CREATE POLICY "csp_insert" ON client_session_packages
  FOR INSERT WITH CHECK (is_org_admin(organization_id));

CREATE POLICY "csp_update" ON client_session_packages
  FOR UPDATE USING (is_org_admin(organization_id));

CREATE POLICY "csp_delete" ON client_session_packages
  FOR DELETE USING (is_org_admin(organization_id));

-- ============================================================
-- Index
-- ============================================================
CREATE INDEX idx_service_packages_org ON service_packages(organization_id) WHERE is_active = true;
CREATE INDEX idx_csp_client ON client_session_packages(client_person_id, organization_id);
CREATE INDEX idx_csp_status ON client_session_packages(status, expires_at);
CREATE INDEX idx_bookings_package ON bookings(client_package_id) WHERE client_package_id IS NOT NULL;
;
