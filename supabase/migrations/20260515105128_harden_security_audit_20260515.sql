-- Security audit hardening (2026-05-15)
--
-- Scope:
-- - Lock down legacy/public full-access policies on operational/patient-memory tables.
-- - Stop deriving JWT authorization claims from user-editable metadata.
-- - Add a defense-in-depth guard against self-escalation through public.persons.

-- ---------------------------------------------------------------------------
-- 1. Replace public full-access policies with service-role-only access.
-- ---------------------------------------------------------------------------

drop policy if exists "agent runs full access" on public.agent_runs;
create policy "agent_runs_service_role_all"
  on public.agent_runs
  as permissive
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
revoke all on table public.agent_runs from public, anon, authenticated;
grant select, insert, update, delete on table public.agent_runs to service_role;
drop policy if exists "background jobs full access" on public.background_jobs;
create policy "background_jobs_service_role_all"
  on public.background_jobs
  as permissive
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
revoke all on table public.background_jobs from public, anon, authenticated;
grant select, insert, update, delete on table public.background_jobs to service_role;
drop policy if exists "patient memories full access" on public.patient_memories;
create policy "patient_memories_service_role_all"
  on public.patient_memories
  as permissive
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
revoke all on table public.patient_memories from public, anon, authenticated;
grant select, insert, update, delete on table public.patient_memories to service_role;
drop policy if exists "pilot encounters full access" on public.pilot_encounters;
create policy "pilot_encounters_service_role_all"
  on public.pilot_encounters
  as permissive
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
revoke all on table public.pilot_encounters from public, anon, authenticated;
grant select, insert, update, delete on table public.pilot_encounters to service_role;
drop policy if exists "pilot patients full access" on public.pilot_patients;
create policy "pilot_patients_service_role_all"
  on public.pilot_patients
  as permissive
  for all
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
revoke all on table public.pilot_patients from public, anon, authenticated;
grant select, insert, update, delete on table public.pilot_patients to service_role;
-- ---------------------------------------------------------------------------
-- 2. Authorization claims must come from app_metadata, not user_metadata.
-- ---------------------------------------------------------------------------

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable security invoker
set search_path to ''
as $function$
declare
  claims jsonb;
  user_role text;
begin
  claims := coalesce(event->'claims', '{}'::jsonb);

  user_role := coalesce(
    event->'user'->'app_metadata'->>'role',
    event->'app_metadata'->>'role',
    event->'claims'->'app_metadata'->>'role'
  );

  if user_role is not null and user_role <> '' then
    claims := jsonb_set(claims, '{app_role}', to_jsonb(user_role::text), true);
  else
    claims := claims - 'app_role';
  end if;

  event := jsonb_set(event, '{claims}', claims, true);
  return event;
end;
$function$;
grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from public, anon, authenticated;
create or replace function public.get_current_user_role()
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_role text;
begin
  select raw_app_meta_data->>'role'
    into v_role
  from auth.users
  where id = (select auth.uid());

  return coalesce(v_role, 'anonymous');
end;
$function$;
revoke execute on function public.get_current_user_role() from public, anon;
grant execute on function public.get_current_user_role() to authenticated, service_role;
update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) - 'role' - 'roles' - 'person_id'
where coalesce(raw_user_meta_data, '{}'::jsonb) ?| array['role', 'roles', 'person_id'];
-- ---------------------------------------------------------------------------
-- 3. Harden shared RLS helper functions.
-- ---------------------------------------------------------------------------

create or replace function public.get_my_person_id()
returns uuid
language sql
stable security definer
set search_path to ''
as $function$
  select p.id
  from public.persons as p
  where p.auth_user_id = (select auth.uid())
  limit 1;
$function$;
revoke execute on function public.get_my_person_id() from public, anon;
grant execute on function public.get_my_person_id() to authenticated, service_role;
create or replace function public.get_my_org_ids_internal()
returns table(organization_id uuid)
language sql
stable security definer
set search_path to ''
as $function$
  select om.organization_id
  from public.organization_members as om
  where om.person_id = public.get_my_person_id()
    and om.status = 'active'
    and om.deleted_at is null;
$function$;
revoke execute on function public.get_my_org_ids_internal() from public, anon;
grant execute on function public.get_my_org_ids_internal() to authenticated, service_role;
create or replace function public.is_org_member(p_org_id uuid)
returns boolean
language sql
stable security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.organization_members as om
    where om.organization_id = p_org_id
      and om.person_id = public.get_my_person_id()
      and om.status = 'active'
      and om.deleted_at is null
  );
$function$;
revoke execute on function public.is_org_member(uuid) from public, anon;
grant execute on function public.is_org_member(uuid) to authenticated, service_role;
create or replace function public.is_org_admin(p_org_id uuid)
returns boolean
language sql
stable security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.organization_members as om
    where om.organization_id = p_org_id
      and om.person_id = public.get_my_person_id()
      and om.role in ('owner', 'admin')
      and om.status = 'active'
      and om.deleted_at is null
  );
$function$;
revoke execute on function public.is_org_admin(uuid) from public, anon;
grant execute on function public.is_org_admin(uuid) to authenticated, service_role;
create or replace function public.has_org_permission(p_org_id uuid, p_permission text)
returns boolean
language sql
stable security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.organization_members as om
    where om.organization_id = p_org_id
      and om.person_id = public.get_my_person_id()
      and (om.role in ('owner', 'admin') or om.permissions ? p_permission)
      and om.status = 'active'
      and om.deleted_at is null
  );
$function$;
revoke execute on function public.has_org_permission(uuid, text) from public, anon;
grant execute on function public.has_org_permission(uuid, text) to authenticated, service_role;
create or replace function public.is_my_person(p_person_id uuid)
returns boolean
language sql
stable security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.persons as p
    where p.id = p_person_id
      and p.auth_user_id = (select auth.uid())
  );
$function$;
revoke execute on function public.is_my_person(uuid) from public, anon;
grant execute on function public.is_my_person(uuid) to authenticated, service_role;
create or replace function public.is_platform_admin()
returns boolean
language sql
stable security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.platform_admins as pa
    join public.persons as p on p.id = pa.person_id
    where p.auth_user_id = (select auth.uid())
      and pa.is_active = true
  );
$function$;
revoke execute on function public.is_platform_admin() from public, anon;
grant execute on function public.is_platform_admin() to authenticated, service_role;
create or replace function public.has_platform_permission(
  p_resource text,
  p_action text default 'read'::text
)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  admin_permissions jsonb;
begin
  select pa.permissions
    into admin_permissions
  from public.platform_admins as pa
  join public.persons as p on p.id = pa.person_id
  where p.auth_user_id = (select auth.uid())
    and pa.is_active = true
  limit 1;

  if admin_permissions is null then
    return false;
  end if;

  return coalesce(
    (admin_permissions->p_resource->>p_action)::boolean,
    false
  );
end;
$function$;
revoke execute on function public.has_platform_permission(text, text) from public, anon;
grant execute on function public.has_platform_permission(text, text) to authenticated, service_role;
-- ---------------------------------------------------------------------------
-- 4. Scope sensitive prompt lifecycle policies to authenticated admins.
-- ---------------------------------------------------------------------------

drop policy if exists "org_admin_read" on public.prompt_templates;
drop policy if exists "prompt_templates_platform_admin_select" on public.prompt_templates;
drop policy if exists "prompt_templates_platform_admin_insert" on public.prompt_templates;
drop policy if exists "prompt_templates_platform_admin_update" on public.prompt_templates;
drop policy if exists "prompt_templates_platform_admin_delete" on public.prompt_templates;
create policy "prompt_templates_platform_admin_select"
  on public.prompt_templates
  as permissive
  for select
  to authenticated
  using ((select public.is_platform_admin()));
create policy "prompt_templates_platform_admin_insert"
  on public.prompt_templates
  as permissive
  for insert
  to authenticated
  with check ((select public.is_platform_admin()));
create policy "prompt_templates_platform_admin_update"
  on public.prompt_templates
  as permissive
  for update
  to authenticated
  using ((select public.is_platform_admin()))
  with check ((select public.is_platform_admin()));
create policy "prompt_templates_platform_admin_delete"
  on public.prompt_templates
  as permissive
  for delete
  to authenticated
  using ((select public.is_platform_admin()));
revoke all on table public.prompt_templates from public, anon;
grant select, insert, update, delete on table public.prompt_templates to authenticated, service_role;
drop policy if exists "org_member_read" on public.prompt_evolution_rules;
drop policy if exists "prompt_evolution_rules_platform_admin_insert" on public.prompt_evolution_rules;
drop policy if exists "prompt_evolution_rules_platform_admin_update" on public.prompt_evolution_rules;
drop policy if exists "prompt_evolution_rules_platform_admin_delete" on public.prompt_evolution_rules;
create policy "org_member_read"
  on public.prompt_evolution_rules
  as permissive
  for select
  to authenticated
  using (public.is_org_member(organization_id) or (select public.is_platform_admin()));
create policy "prompt_evolution_rules_platform_admin_insert"
  on public.prompt_evolution_rules
  as permissive
  for insert
  to authenticated
  with check ((select public.is_platform_admin()));
create policy "prompt_evolution_rules_platform_admin_update"
  on public.prompt_evolution_rules
  as permissive
  for update
  to authenticated
  using ((select public.is_platform_admin()))
  with check ((select public.is_platform_admin()));
create policy "prompt_evolution_rules_platform_admin_delete"
  on public.prompt_evolution_rules
  as permissive
  for delete
  to authenticated
  using ((select public.is_platform_admin()));
revoke all on table public.prompt_evolution_rules from public, anon;
grant select, insert, update, delete on table public.prompt_evolution_rules to authenticated, service_role;
-- ---------------------------------------------------------------------------
-- 5. Optimize remaining platform-admin RLS predicates.
-- ---------------------------------------------------------------------------

drop policy if exists "aft_admin_insert" on public.assessment_form_templates;
drop policy if exists "aft_admin_update" on public.assessment_form_templates;
drop policy if exists "aft_admin_delete" on public.assessment_form_templates;
create policy "aft_admin_insert"
  on public.assessment_form_templates
  as permissive
  for insert
  to authenticated
  with check ((select public.is_platform_admin()));
create policy "aft_admin_update"
  on public.assessment_form_templates
  as permissive
  for update
  to authenticated
  using ((select public.is_platform_admin()))
  with check ((select public.is_platform_admin()));
create policy "aft_admin_delete"
  on public.assessment_form_templates
  as permissive
  for delete
  to authenticated
  using ((select public.is_platform_admin()));
drop policy if exists "clinical_insights_select_consolidated" on public.clinical_insights;
create policy "clinical_insights_select_consolidated"
  on public.clinical_insights
  as permissive
  for select
  to authenticated
  using (
    organization_id in (
      select om.organization_id
      from public.organization_members as om
      where om.person_id = public.get_my_person_id()
    )
    or (select public.is_platform_admin())
  );
drop policy if exists "admin_insert_exercises" on public.exercises;
drop policy if exists "admin_update_exercises" on public.exercises;
drop policy if exists "admin_delete_exercises" on public.exercises;
create policy "admin_insert_exercises"
  on public.exercises
  as permissive
  for insert
  to authenticated
  with check ((select public.is_platform_admin()));
create policy "admin_update_exercises"
  on public.exercises
  as permissive
  for update
  to authenticated
  using ((select public.is_platform_admin()))
  with check ((select public.is_platform_admin()));
create policy "admin_delete_exercises"
  on public.exercises
  as permissive
  for delete
  to authenticated
  using ((select public.is_platform_admin()));
drop policy if exists "mlpep_select" on public.ml_client_exercise_progress;
drop policy if exists "mlpep_insert_platform_admin" on public.ml_client_exercise_progress;
drop policy if exists "mlpep_update_platform_admin" on public.ml_client_exercise_progress;
drop policy if exists "mlpep_delete_platform_admin" on public.ml_client_exercise_progress;
create policy "mlpep_select"
  on public.ml_client_exercise_progress
  as permissive
  for select
  to authenticated
  using (
    organization_id in (
      select om.organization_id
      from public.organization_members as om
      join public.persons as p on p.id = om.person_id
      where p.auth_user_id = (select auth.uid())
    )
    or (select public.is_platform_admin())
  );
create policy "mlpep_insert_platform_admin"
  on public.ml_client_exercise_progress
  as permissive
  for insert
  to authenticated
  with check ((select public.is_platform_admin()));
create policy "mlpep_update_platform_admin"
  on public.ml_client_exercise_progress
  as permissive
  for update
  to authenticated
  using ((select public.is_platform_admin()))
  with check ((select public.is_platform_admin()));
create policy "mlpep_delete_platform_admin"
  on public.ml_client_exercise_progress
  as permissive
  for delete
  to authenticated
  using ((select public.is_platform_admin()));
drop policy if exists "ml_registry_select_org" on public.ml_model_registry;
drop policy if exists "ml_registry_insert_admin_or_platform" on public.ml_model_registry;
drop policy if exists "ml_registry_update_admin_or_platform" on public.ml_model_registry;
drop policy if exists "ml_registry_delete_admin_or_platform" on public.ml_model_registry;
create policy "ml_registry_select_org"
  on public.ml_model_registry
  as permissive
  for select
  to authenticated
  using (public.is_org_member(organization_id) or (select public.is_platform_admin()));
create policy "ml_registry_insert_admin_or_platform"
  on public.ml_model_registry
  as permissive
  for insert
  to authenticated
  with check (public.is_org_admin(organization_id) or (select public.is_platform_admin()));
create policy "ml_registry_update_admin_or_platform"
  on public.ml_model_registry
  as permissive
  for update
  to authenticated
  using (public.is_org_admin(organization_id) or (select public.is_platform_admin()))
  with check (public.is_org_admin(organization_id) or (select public.is_platform_admin()));
create policy "ml_registry_delete_admin_or_platform"
  on public.ml_model_registry
  as permissive
  for delete
  to authenticated
  using (public.is_org_admin(organization_id) or (select public.is_platform_admin()));
drop policy if exists "ml_pred_insert_org_or_platform" on public.ml_predictions;
drop policy if exists "ml_pred_select_org_or_platform" on public.ml_predictions;
drop policy if exists "ml_pred_update_platform_admin" on public.ml_predictions;
drop policy if exists "ml_pred_delete_platform_admin" on public.ml_predictions;
create policy "ml_pred_insert_org_or_platform"
  on public.ml_predictions
  as permissive
  for insert
  to authenticated
  with check (public.is_org_member(organization_id) or (select public.is_platform_admin()));
create policy "ml_pred_select_org_or_platform"
  on public.ml_predictions
  as permissive
  for select
  to authenticated
  using (public.is_org_member(organization_id) or (select public.is_platform_admin()));
create policy "ml_pred_update_platform_admin"
  on public.ml_predictions
  as permissive
  for update
  to authenticated
  using ((select public.is_platform_admin()))
  with check ((select public.is_platform_admin()));
create policy "ml_pred_delete_platform_admin"
  on public.ml_predictions
  as permissive
  for delete
  to authenticated
  using ((select public.is_platform_admin()));
drop policy if exists "organizations_select_consolidated" on public.organizations;
create policy "organizations_select_consolidated"
  on public.organizations
  as permissive
  for select
  to authenticated
  using (
    (select public.is_platform_admin())
    or id in (
      select my_orgs.organization_id
      from public.get_my_org_ids_internal() as my_orgs(organization_id)
    )
  );
-- ---------------------------------------------------------------------------
-- 6. Defense in depth for public.persons self-update policy.
-- ---------------------------------------------------------------------------

revoke update (auth_user_id, user_type, roles, is_active, source_type, created_by, anonymized_at)
  on table public.persons
  from public, anon, authenticated;
create or replace function public.prevent_person_authority_self_update()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if (select auth.role()) = 'authenticated'
     and old.auth_user_id = (select auth.uid()) then
    if new.auth_user_id is distinct from old.auth_user_id
       or new.user_type is distinct from old.user_type
       or new.roles is distinct from old.roles
       or new.is_active is distinct from old.is_active
       or new.source_type is distinct from old.source_type
       or new.created_by is distinct from old.created_by
       or new.anonymized_at is distinct from old.anonymized_at then
      raise exception 'Cannot update authority-managed person fields';
    end if;
  end if;

  return new;
end;
$function$;
revoke execute on function public.prevent_person_authority_self_update() from public, anon, authenticated;
drop trigger if exists prevent_person_authority_self_update on public.persons;
create trigger prevent_person_authority_self_update
  before update on public.persons
  for each row
  execute function public.prevent_person_authority_self_update();
