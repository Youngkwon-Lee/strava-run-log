-- Continue Supabase security hardening:
-- 1. Keep RLS helper functions callable by policies through public SECURITY INVOKER wrappers.
-- 2. Move privileged reads to a private, non-exposed schema.
-- 3. Remove default public/anon/authenticated EXECUTE from remaining public SECURITY DEFINER RPCs.
-- 4. Stop broad listing of the public exercise-media storage bucket.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;
create or replace function private.get_my_person_id()
returns uuid
language sql
stable
security definer
set search_path to ''
as $$
  select p.id
  from public.persons as p
  where p.auth_user_id = (select auth.uid())
  limit 1;
$$;
create or replace function private.get_my_org_ids_internal()
returns table(organization_id uuid)
language sql
stable
security definer
set search_path to ''
as $$
  select om.organization_id
  from public.organization_members as om
  where om.person_id = private.get_my_person_id()
    and om.status = 'active'
    and om.deleted_at is null;
$$;
create or replace function private.get_my_org_ids()
returns table(organization_id uuid)
language sql
stable
security definer
set search_path to ''
as $$
  select om.organization_id
  from public.organization_members as om
  where om.person_id = private.get_my_person_id()
    and om.status = 'active'
    and om.deleted_at is null;
$$;
create or replace function private.is_org_member(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.organization_members as om
    where om.organization_id = p_org_id
      and om.person_id = private.get_my_person_id()
      and om.status = 'active'
      and om.deleted_at is null
  );
$$;
create or replace function private.is_org_admin(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.organization_members as om
    where om.organization_id = p_org_id
      and om.person_id = private.get_my_person_id()
      and om.role in ('owner', 'admin')
      and om.status = 'active'
      and om.deleted_at is null
  );
$$;
create or replace function private.has_org_permission(p_org_id uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.organization_members as om
    where om.organization_id = p_org_id
      and om.person_id = private.get_my_person_id()
      and (om.role in ('owner', 'admin') or om.permissions ? p_permission)
      and om.status = 'active'
      and om.deleted_at is null
  );
$$;
create or replace function private.is_my_person(p_person_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.persons as p
    where p.id = p_person_id
      and p.auth_user_id = (select auth.uid())
  );
$$;
create or replace function private.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.platform_admins as pa
    join public.persons as p on p.id = pa.person_id
    where p.auth_user_id = (select auth.uid())
      and pa.is_active = true
  );
$$;
create or replace function private.get_platform_admin_role()
returns text
language sql
stable
security definer
set search_path to ''
as $$
  select pa.role
  from public.platform_admins as pa
  join public.persons as p on p.id = pa.person_id
  where p.auth_user_id = (select auth.uid())
    and pa.is_active = true
  limit 1;
$$;
create or replace function private.has_platform_permission(
  p_resource text,
  p_action text default 'read'
)
returns boolean
language plpgsql
stable
security definer
set search_path to ''
as $$
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
$$;
create or replace function private.can_access_client_via_org(p_person_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.org_clients as oc
    join public.organization_members as om on om.organization_id = oc.organization_id
    where oc.person_id = p_person_id
      and om.person_id = private.get_my_person_id()
      and om.status = 'active'
      and om.deleted_at is null
  );
$$;
revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated, service_role;
alter default privileges in schema private revoke execute on functions from public, anon;
create or replace function public.get_my_person_id()
returns uuid
language sql
stable
security invoker
set search_path to ''
as $$
  select private.get_my_person_id();
$$;
create or replace function public.get_my_org_ids_internal()
returns table(organization_id uuid)
language sql
stable
security invoker
set search_path to ''
as $$
  select * from private.get_my_org_ids_internal();
$$;
create or replace function public.get_my_org_ids()
returns table(organization_id uuid)
language sql
stable
security invoker
set search_path to ''
as $$
  select * from private.get_my_org_ids();
$$;
create or replace function public.is_org_member(p_org_id uuid)
returns boolean
language sql
stable
security invoker
set search_path to ''
as $$
  select private.is_org_member(p_org_id);
$$;
create or replace function public.is_org_admin(p_org_id uuid)
returns boolean
language sql
stable
security invoker
set search_path to ''
as $$
  select private.is_org_admin(p_org_id);
$$;
create or replace function public.has_org_permission(p_org_id uuid, p_permission text)
returns boolean
language sql
stable
security invoker
set search_path to ''
as $$
  select private.has_org_permission(p_org_id, p_permission);
$$;
create or replace function public.is_my_person(p_person_id uuid)
returns boolean
language sql
stable
security invoker
set search_path to ''
as $$
  select private.is_my_person(p_person_id);
$$;
create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security invoker
set search_path to ''
as $$
  select private.is_platform_admin();
$$;
create or replace function public.get_platform_admin_role()
returns text
language sql
stable
security invoker
set search_path to ''
as $$
  select private.get_platform_admin_role();
$$;
create or replace function public.has_platform_permission(
  p_resource text,
  p_action text default 'read'
)
returns boolean
language sql
stable
security invoker
set search_path to ''
as $$
  select private.has_platform_permission(p_resource, p_action);
$$;
create or replace function public.can_access_client_via_org(p_person_id uuid)
returns boolean
language sql
stable
security invoker
set search_path to ''
as $$
  select private.can_access_client_via_org(p_person_id);
$$;
revoke execute on function public.get_my_person_id() from public, anon;
revoke execute on function public.get_my_org_ids_internal() from public, anon;
revoke execute on function public.get_my_org_ids() from public, anon;
revoke execute on function public.is_org_member(uuid) from public, anon;
revoke execute on function public.is_org_admin(uuid) from public, anon;
revoke execute on function public.has_org_permission(uuid, text) from public, anon;
revoke execute on function public.is_my_person(uuid) from public, anon;
revoke execute on function public.is_platform_admin() from public, anon;
revoke execute on function public.get_platform_admin_role() from public, anon;
revoke execute on function public.has_platform_permission(text, text) from public, anon;
revoke execute on function public.can_access_client_via_org(uuid) from public, anon;
grant execute on function public.get_my_person_id() to authenticated, service_role;
grant execute on function public.get_my_org_ids_internal() to authenticated, service_role;
grant execute on function public.get_my_org_ids() to authenticated, service_role;
grant execute on function public.is_org_member(uuid) to authenticated, service_role;
grant execute on function public.is_org_admin(uuid) to authenticated, service_role;
grant execute on function public.has_org_permission(uuid, text) to authenticated, service_role;
grant execute on function public.is_my_person(uuid) to authenticated, service_role;
grant execute on function public.is_platform_admin() to authenticated, service_role;
grant execute on function public.get_platform_admin_role() to authenticated, service_role;
grant execute on function public.has_platform_permission(text, text) to authenticated, service_role;
grant execute on function public.can_access_client_via_org(uuid) to authenticated, service_role;
do $$
declare
  routine regprocedure;
begin
  for routine in
    select p.oid::regprocedure
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', routine);
    execute format('grant execute on function %s to service_role', routine);
  end loop;
end
$$;
drop policy if exists "exercise_media_public_read" on storage.objects;
