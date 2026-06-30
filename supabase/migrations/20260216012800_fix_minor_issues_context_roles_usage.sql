-- ============================================
-- Issue 1: service_context → care_context 통합
-- ============================================

-- 1a. Fix is_medical_organization() to use care_context with correct values
CREATE OR REPLACE FUNCTION is_medical_organization(p_organization_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $fn$
DECLARE
  v_care_context TEXT;
BEGIN
  SELECT care_context INTO v_care_context
  FROM organizations
  WHERE id = p_organization_id;
  RETURN v_care_context IN ('medical', 'mixed');
END;
$fn$;

-- 1b. Fix is_wellness_only_organization() to use care_context
CREATE OR REPLACE FUNCTION is_wellness_only_organization(p_organization_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $fn$
DECLARE
  v_care_context TEXT;
BEGIN
  SELECT care_context INTO v_care_context
  FROM organizations
  WHERE id = p_organization_id;
  RETURN v_care_context = 'non_medical';
END;
$fn$;

-- 1c. Drop dependent views
DROP VIEW IF EXISTS care_plans_with_goals_v;
DROP VIEW IF EXISTS v_platform_organizations;

-- 1d. Recreate care_plans_with_goals_v without service_context → use care_context
CREATE VIEW care_plans_with_goals_v AS
SELECT cp.id, cp.fhir_id, cp.status, cp.intent, cp.category, cp.title, cp.description,
    cp.subject_person_id AS subject_id, cp.author_id, cp.organization_id,
    cp.period_start, cp.period_end, cp.activities, cp.created_at, cp.updated_at,
    (p.first_name || ' ' || p.last_name) AS patient_name,
    (a.first_name || ' ' || a.last_name) AS author_name,
    o.name AS organization_name,
    o.care_context,
    (SELECT count(*) FROM goals g WHERE g.care_plan_id = cp.id) AS goal_count,
    (SELECT count(*) FROM goals g WHERE g.care_plan_id = cp.id AND g.lifecycle_status = 'active') AS active_goal_count,
    (SELECT count(*) FROM goals g WHERE g.care_plan_id = cp.id AND g.lifecycle_status = 'completed') AS completed_goal_count
FROM care_plans cp
LEFT JOIN persons p ON cp.subject_person_id = p.id
LEFT JOIN persons a ON cp.author_id = a.id
LEFT JOIN organizations o ON cp.organization_id = o.id;

-- 1e. Recreate v_platform_organizations without service_context
CREATE VIEW v_platform_organizations AS
SELECT o.id, o.name, o.display_name, o.care_context, o.status, o.created_at, o.updated_at,
    (SELECT count(*) FROM organization_members om WHERE om.organization_id = o.id) AS member_count,
    (SELECT count(*) FROM encounters e WHERE e.organization_id = o.id) AS encounter_count,
    (SELECT p.display_name FROM organization_members om JOIN persons p ON om.person_id = p.id WHERE om.organization_id = o.id AND om.role = 'owner' LIMIT 1) AS owner_name
FROM organizations o;

-- 1f. Drop service_context index + constraint + column
DROP INDEX IF EXISTS idx_organizations_service_context;
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_service_context_check;
ALTER TABLE organizations DROP COLUMN IF EXISTS service_context;

-- ============================================
-- Issue 2: clinic_onboarding roles dynamic
-- ============================================
DROP FUNCTION IF EXISTS clinic_onboarding(text, text, text, text, text, text, text, text);

CREATE FUNCTION clinic_onboarding(
  p_org_name text, p_first_name text, p_last_name text,
  p_email text, p_phone text, p_expert_type text,
  p_org_type text, p_care_context text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_user_id UUID; v_person_id UUID; v_org_id UUID; v_member_id UUID;
  v_roles TEXT[];
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT id INTO v_person_id FROM persons WHERE auth_user_id = v_user_id;
  IF v_person_id IS NOT NULL THEN RAISE EXCEPTION 'Person already exists'; END IF;

  v_roles := CASE
    WHEN p_care_context = 'medical' THEN ARRAY['therapist']::TEXT[]
    WHEN p_care_context = 'non_medical' THEN ARRAY['trainer']::TEXT[]
    ELSE ARRAY['therapist', 'trainer']::TEXT[]
  END;

  INSERT INTO persons (auth_user_id, first_name, last_name, email, phone, user_type, expert_type, roles, source_type, onboarding_status)
  VALUES (v_user_id, p_first_name, p_last_name, p_email, p_phone, 'professional', p_expert_type, v_roles, 'onboarding', 'completed')
  RETURNING id INTO v_person_id;

  INSERT INTO organizations (name, display_name, org_type, care_context, status)
  VALUES (p_org_name, p_org_name, p_org_type, p_care_context, 'active')
  RETURNING id INTO v_org_id;

  INSERT INTO organization_members (organization_id, person_id, role, status)
  VALUES (v_org_id, v_person_id, 'owner', 'active')
  RETURNING id INTO v_member_id;

  RETURN jsonb_build_object('success', true, 'person_id', v_person_id, 'organization_id', v_org_id, 'member_id', v_member_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$fn$;

-- ============================================
-- Issue 3: organization_usage 역할 명확화
-- ============================================
COMMENT ON TABLE organization_usage IS 'Periodic aggregate usage snapshots per org (person_count, storage, AI calls). Calculated by cron.';
COMMENT ON TABLE subscription_usage IS 'Per-transaction credit ledger. Tracks encounter/attendance credit deductions with hold/commit/release/void lifecycle.';

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'organization_usage' AND policyname = 'org_members_read_usage_stats') THEN
    CREATE POLICY org_members_read_usage_stats ON organization_usage FOR SELECT USING (is_org_member(organization_id));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'organization_usage' AND policyname = 'service_role_manage_usage_stats') THEN
    CREATE POLICY service_role_manage_usage_stats ON organization_usage FOR ALL TO service_role USING (true);
  END IF;
END $$;;
