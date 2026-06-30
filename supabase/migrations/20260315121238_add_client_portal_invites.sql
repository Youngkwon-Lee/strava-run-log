create table if not exists public.client_portal_invites (
    id uuid primary key default gen_random_uuid(),
    org_client_id uuid not null references public.org_clients(id) on delete cascade,
    organization_id uuid not null references public.organizations(id) on delete cascade,
    person_id uuid not null references public.persons(id) on delete cascade,
    code text not null,
    created_by uuid references public.persons(id) on delete set null,
    expires_at timestamp with time zone not null,
    claimed_at timestamp with time zone,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint client_portal_invites_code_check check (char_length(code) between 6 and 24)
);

create unique index if not exists client_portal_invites_code_key
    on public.client_portal_invites (code);

create index if not exists idx_client_portal_invites_org_client_id
    on public.client_portal_invites (org_client_id);

create index if not exists idx_client_portal_invites_org_id
    on public.client_portal_invites (organization_id);

create unique index if not exists uq_client_portal_invites_org_client_pending
    on public.client_portal_invites (org_client_id)
    where claimed_at is null and revoked_at is null;

alter table public.client_portal_invites enable row level security;

create or replace function public.claim_client_portal_invite_identity(
    p_invite_id uuid,
    p_target_person_id uuid,
    p_auth_user_id uuid,
    p_placeholder_person_id uuid default null,
    p_email text default null
) returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
    v_invite public.client_portal_invites%rowtype;
    v_deleted_count integer := 0;
begin
    if auth.uid() is not null then
        raise exception 'claim_client_portal_invite_identity can only be called via service_role';
    end if;

    select *
      into v_invite
      from public.client_portal_invites
     where id = p_invite_id
     for update;

    if not found then
        raise exception 'Client portal invite not found';
    end if;

    if v_invite.person_id <> p_target_person_id then
        raise exception 'Client portal invite target mismatch';
    end if;

    if v_invite.revoked_at is not null then
        raise exception 'Client portal invite revoked';
    end if;

    if v_invite.claimed_at is not null then
        return;
    end if;

    if v_invite.expires_at < now() then
        raise exception 'Client portal invite expired';
    end if;

    if p_placeholder_person_id is not null and p_placeholder_person_id <> p_target_person_id then
        delete from public.persons
         where id = p_placeholder_person_id
           and auth_user_id = p_auth_user_id;

        get diagnostics v_deleted_count = row_count;
        if v_deleted_count <> 1 then
            raise exception 'Client portal placeholder person not found';
        end if;
    end if;

    update public.persons
       set auth_user_id = p_auth_user_id,
           email = coalesce(public.persons.email, nullif(trim(p_email), '')),
           updated_at = now()
     where id = p_target_person_id
       and (auth_user_id is null or auth_user_id = p_auth_user_id);

    if not found then
        raise exception 'Client portal target person is already linked';
    end if;

    update public.client_portal_invites
       set claimed_at = now(),
           updated_at = now()
     where id = p_invite_id
       and claimed_at is null;
end;
$$;;
