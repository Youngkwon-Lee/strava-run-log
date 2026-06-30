-- Step 1: DROP old constraints first
ALTER TABLE organization_members DROP CONSTRAINT IF EXISTS organization_members_role_check;
ALTER TABLE organization_invites DROP CONSTRAINT IF EXISTS organization_invites_role_check;

-- Step 2: Update existing data
UPDATE organization_members SET role = 'provider' WHERE role IN ('clinician','trainer');
UPDATE organization_members SET role = 'staff' WHERE role = 'assistant';
UPDATE organization_members SET role = 'client' WHERE role = 'patient';

-- Step 3: Add new constraints
ALTER TABLE organization_members ADD CONSTRAINT organization_members_role_check CHECK (role IN ('owner','admin','provider','staff','researcher','client','caregiver','viewer'));
ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_role_check CHECK (role::text IN ('owner','admin','provider','staff','researcher','client','caregiver','viewer'));

-- Step 4: Bulk update RLS policies
DO $block$
DECLARE
  pol RECORD;
  new_qual TEXT;
  new_check TEXT;
  alter_sql TEXT;
BEGIN
  FOR pol IN
    SELECT p.polname, c.relname as tablename, p.polrelid,
           pg_get_expr(p.polqual, p.polrelid) as qual_expr,
           CASE WHEN p.polwithcheck IS NOT NULL THEN pg_get_expr(p.polwithcheck, p.polrelid) ELSE NULL END as check_expr
    FROM pg_policy p
    JOIN pg_class c ON p.polrelid = c.oid
    WHERE c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    AND (
      pg_get_expr(p.polqual, p.polrelid) LIKE '%''clinician''%'
      OR pg_get_expr(p.polqual, p.polrelid) LIKE '%''trainer''%'
      OR pg_get_expr(p.polqual, p.polrelid) LIKE '%''assistant''%'
      OR (p.polwithcheck IS NOT NULL AND (
        pg_get_expr(p.polwithcheck, p.polrelid) LIKE '%''clinician''%'
        OR pg_get_expr(p.polwithcheck, p.polrelid) LIKE '%''trainer''%'
        OR pg_get_expr(p.polwithcheck, p.polrelid) LIKE '%''assistant''%'
      ))
    )
  LOOP
    new_qual := pol.qual_expr;
    IF new_qual IS NOT NULL THEN
      new_qual := replace(new_qual, '''clinician''::text', '''provider''::text');
      new_qual := replace(new_qual, '''trainer''::text', '''provider''::text');
      new_qual := replace(new_qual, '''assistant''::text', '''staff''::text');
      new_qual := replace(new_qual, '''provider''::text, ''provider''::text', '''provider''::text');
      alter_sql := format('ALTER POLICY %I ON %I USING (%s)', pol.polname, pol.tablename, new_qual);
      EXECUTE alter_sql;
    END IF;
    IF pol.check_expr IS NOT NULL THEN
      new_check := pol.check_expr;
      new_check := replace(new_check, '''clinician''::text', '''provider''::text');
      new_check := replace(new_check, '''trainer''::text', '''provider''::text');
      new_check := replace(new_check, '''assistant''::text', '''staff''::text');
      new_check := replace(new_check, '''provider''::text, ''provider''::text', '''provider''::text');
      alter_sql := format('ALTER POLICY %I ON %I WITH CHECK (%s)', pol.polname, pol.tablename, new_check);
      EXECUTE alter_sql;
    END IF;
  END LOOP;
END $block$;

-- Step 5: Fix exercises JWT policy
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'exercises' AND policyname = 'Patients can view exercises') THEN
    DROP POLICY "Patients can view exercises" ON exercises;
    CREATE POLICY "Clients can view exercises" ON exercises FOR SELECT USING ((auth.jwt() ->> 'app_role') = 'client');
  END IF;
END $$;
;
