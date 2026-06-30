
-- Recreate create_account_chain with service_role guard
-- auth.uid() is null when called via service_role → only service_role can invoke
DROP FUNCTION IF EXISTS public.create_account_chain(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.create_account_chain(
  p_auth_user_id UUID,
  p_email TEXT,
  p_display_name TEXT DEFAULT NULL
)
RETURNS TABLE(out_person_id UUID, out_organization_id UUID, out_member_id UUID, out_was_existing BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_person_id UUID;
  v_org_id UUID;
  v_member_id UUID;
  v_was_existing BOOLEAN := FALSE;
  v_first_name TEXT;
  v_slug TEXT;
BEGIN
  -- Guard: only service_role (auth.uid() is null) can call this
  IF auth.uid() IS NOT NULL THEN
    RAISE EXCEPTION 'create_account_chain can only be called via service_role';
  END IF;

  v_first_name := COALESCE(NULLIF(TRIM(p_display_name), ''), split_part(p_email, '@', 1));

  -- 1. Person: upsert (trigger may have already created)
  INSERT INTO persons (auth_user_id, email, first_name, user_type, source_type, onboarding_status)
  VALUES (p_auth_user_id, p_email, v_first_name, 'professional', 'self_registered', 'pending')
  ON CONFLICT (auth_user_id) DO NOTHING;

  SELECT id INTO v_person_id FROM persons WHERE auth_user_id = p_auth_user_id;
  IF v_person_id IS NULL THEN
    RAISE EXCEPTION 'Failed to create/find person for %', p_auth_user_id;
  END IF;

  -- 2. Check existing membership
  SELECT om.organization_id, om.id INTO v_org_id, v_member_id
  FROM organization_members om
  WHERE om.person_id = v_person_id AND om.status = 'active' AND om.deleted_at IS NULL
  LIMIT 1;

  IF v_org_id IS NOT NULL THEN
    RETURN QUERY SELECT v_person_id, v_org_id, v_member_id, TRUE;
    RETURN;
  END IF;

  -- 3. Organization: deterministic slug
  v_slug := 'org-' || REPLACE(p_auth_user_id::TEXT, '-', '');

  INSERT INTO organizations (name, slug, display_name, org_type, care_context,
    settings, created_at, updated_at)
  VALUES (v_slug, v_slug, v_first_name || '''s Workspace', 'clinic', 'medical',
    '{"is_solo_practice":true,"created_via":"create_account_chain"}'::jsonb, NOW(), NOW())
  ON CONFLICT (slug) DO NOTHING;

  SELECT id INTO v_org_id FROM organizations WHERE slug = v_slug;
  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Failed to create/find organization for %', p_auth_user_id;
  END IF;

  -- 4. Membership
  INSERT INTO organization_members (organization_id, person_id, role, status, joined_at)
  VALUES (v_org_id, v_person_id, 'owner', 'active', NOW())
  ON CONFLICT (organization_id, person_id) DO NOTHING
  RETURNING id INTO v_member_id;

  IF v_member_id IS NULL THEN
    SELECT om.id INTO v_member_id FROM organization_members om
    WHERE om.organization_id = v_org_id AND om.person_id = v_person_id;
    v_was_existing := TRUE;
  END IF;

  RETURN QUERY SELECT v_person_id, v_org_id, v_member_id, v_was_existing;
END;
$$;

GRANT EXECUTE ON FUNCTION create_account_chain(UUID, TEXT, TEXT) TO service_role;
REVOKE EXECUTE ON FUNCTION create_account_chain(UUID, TEXT, TEXT) FROM anon, authenticated;
;
