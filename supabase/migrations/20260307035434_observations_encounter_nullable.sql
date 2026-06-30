
-- Phase 2: Episode-centric 철학 완성
-- observations.encounter_id → nullable (홈트/러닝/웨어러블 세션 지원)

-- 1. encounter_id NOT NULL 제거
ALTER TABLE observations ALTER COLUMN encounter_id DROP NOT NULL;

-- 2. 최소 하나의 컨텍스트 필수 (encounter OR session)
ALTER TABLE observations
  ADD CONSTRAINT obs_has_context
  CHECK (encounter_id IS NOT NULL OR activity_session_id IS NOT NULL);

-- 3. RLS 정책 수정 — encounter_id NULL인 세션 관측값 지원

-- 3a. observations_clinician_insert: INSERT WITH CHECK
DROP POLICY IF EXISTS "observations_clinician_insert" ON observations;
CREATE POLICY "observations_clinician_insert" ON observations
  FOR INSERT
  WITH CHECK (
    -- 기본: org member (provider 이상)
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = (
        SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid()
      )
      AND om.organization_id = observations.organization_id
      AND om.role IN ('owner', 'admin', 'provider')
    )
    AND (
      -- Encounter-based: encounter org+subject 일치 확인
      (
        observations.encounter_id IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM encounters e
          WHERE e.id = observations.encounter_id
            AND e.organization_id = observations.organization_id
            AND e.subject_person_id = observations.subject_person_id
        )
      )
      OR
      -- Session-only: encounter 없이 activity_session 연결
      (observations.encounter_id IS NULL AND observations.activity_session_id IS NOT NULL)
    )
  );

-- 3b. observations_clinician_update: UPDATE (USING + WITH CHECK)
DROP POLICY IF EXISTS "observations_clinician_update" ON observations;
CREATE POLICY "observations_clinician_update" ON observations
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = (
        SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid()
      )
      AND om.organization_id = observations.organization_id
      AND om.role IN ('owner', 'admin', 'provider')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.person_id = (
        SELECT p.id FROM persons p WHERE p.auth_user_id = auth.uid()
      )
      AND om.organization_id = observations.organization_id
      AND om.role IN ('owner', 'admin', 'provider')
    )
    AND (
      (
        observations.encounter_id IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM encounters e
          WHERE e.id = observations.encounter_id
            AND e.organization_id = observations.organization_id
            AND e.subject_person_id = observations.subject_person_id
        )
      )
      OR
      (observations.encounter_id IS NULL AND observations.activity_session_id IS NOT NULL)
    )
  );

-- 3c. observations_provider_access: SELECT
DROP POLICY IF EXISTS "observations_provider_access" ON observations;
CREATE POLICY "observations_provider_access" ON observations
  FOR SELECT
  USING (
    -- Encounter-based access (기존)
    (
      observations.encounter_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM encounters e
        JOIN organization_members om ON om.organization_id = e.organization_id
        WHERE e.id = observations.encounter_id
          AND om.person_id = get_my_person_id()
          AND om.role IN ('owner', 'admin', 'provider', 'staff')
          AND om.status = 'active'
      )
    )
    OR
    -- Session-only access (org membership)
    (
      observations.encounter_id IS NULL
      AND EXISTS (
        SELECT 1 FROM organization_members om
        WHERE om.organization_id = observations.organization_id
          AND om.person_id = get_my_person_id()
          AND om.role IN ('owner', 'admin', 'provider', 'staff')
          AND om.status = 'active'
      )
    )
  );
;
