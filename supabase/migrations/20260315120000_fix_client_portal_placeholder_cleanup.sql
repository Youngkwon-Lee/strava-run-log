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
    v_placeholder_updated integer := 0;
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
        update public.persons
           set auth_user_id = null,
               email = null,
               is_active = false,
               updated_at = now()
         where id = p_placeholder_person_id
           and auth_user_id = p_auth_user_id;

        get diagnostics v_placeholder_updated = row_count;
        if v_placeholder_updated <> 1 then
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
$$;
