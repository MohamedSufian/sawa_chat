-- =====================================================================
-- Sawa Chat — phase 6: groups with system messages
-- Run in Supabase Dashboard → SQL Editor after 0002.
--
-- Every group change writes a `system` message whose media_meta holds
-- {event, targets[], name?}. The app turns it into a sentence in the
-- reader's language, so nothing language-specific is stored.
-- =====================================================================

create or replace function public.log_group_event(
  p_chat_id uuid,
  p_event text,
  p_targets uuid[] default '{}',
  p_extra jsonb default '{}'
)
returns void
language sql security definer set search_path = public
as $$
  -- clock_timestamp(), not now(): several events in one transaction must stay ordered.
  insert into messages (client_id, chat_id, sender_id, type, media_meta, created_at)
  values (
    gen_random_uuid(), p_chat_id, auth.uid(), 'system',
    jsonb_build_object('event', p_event, 'targets', to_jsonb(p_targets)) || p_extra,
    clock_timestamp()
  );
$$;

-- Internal only: clients must not forge system messages.
revoke execute on function public.log_group_event(uuid, text, uuid[], jsonb) from public, anon, authenticated;

create or replace function public.create_group(
  p_name text,
  p_member_ids uuid[],
  p_avatar_url text default null,
  p_description text default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_me    uuid := auth.uid();
  v_chat  uuid;
  v_added uuid[];
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'name required'; end if;

  insert into chats (type, name, avatar_url, description, created_by)
  values ('group', trim(p_name), p_avatar_url, p_description, v_me)
  returning id into v_chat;

  insert into chat_members (chat_id, user_id, role) values (v_chat, v_me, 'owner');

  with added as (
    insert into chat_members (chat_id, user_id, role)
    select v_chat, m, 'member'
      from unnest(p_member_ids) as m
     where m <> v_me
       and exists (select 1 from profiles where id = m)
       and not is_blocked_between(m, v_me)
    on conflict do nothing
    returning user_id
  )
  select coalesce(array_agg(user_id), '{}') into v_added from added;

  perform log_group_event(v_chat, 'created', '{}', jsonb_build_object('name', trim(p_name)));
  if cardinality(v_added) > 0 then perform log_group_event(v_chat, 'added', v_added); end if;

  return v_chat;
end;
$$;

create or replace function public.add_group_members(p_chat_id uuid, p_member_ids uuid[])
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_added uuid[];
begin
  if not is_chat_admin(p_chat_id) then raise exception 'not allowed'; end if;

  with added as (
    insert into chat_members (chat_id, user_id, role)
    select p_chat_id, m, 'member'
      from unnest(p_member_ids) as m
     where exists (select 1 from profiles where id = m)
       and not is_blocked_between(m, auth.uid())
    on conflict do nothing
    returning user_id
  )
  select coalesce(array_agg(user_id), '{}') into v_added from added;

  if cardinality(v_added) > 0 then perform log_group_event(p_chat_id, 'added', v_added); end if;
end;
$$;

create or replace function public.remove_group_member(p_chat_id uuid, p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_target_role text;
  v_leaving     boolean := p_user_id = auth.uid();
begin
  select role into v_target_role from chat_members where chat_id = p_chat_id and user_id = p_user_id;
  if v_target_role is null then return; end if;

  if not v_leaving and (not is_chat_admin(p_chat_id) or v_target_role = 'owner') then
    raise exception 'not allowed';
  end if;

  -- Log first, while the actor is still a member.
  if v_leaving then
    perform log_group_event(p_chat_id, 'left');
  else
    perform log_group_event(p_chat_id, 'removed', array[p_user_id]);
  end if;

  delete from chat_members where chat_id = p_chat_id and user_id = p_user_id;

  -- If the owner left, promote an admin, or else the longest-standing member.
  if v_target_role = 'owner' then
    update chat_members set role = 'owner'
     where (chat_id, user_id) = (
       select chat_id, user_id from chat_members
        where chat_id = p_chat_id
        order by (role = 'admin') desc, joined_at
        limit 1
     );
  end if;
end;
$$;

create or replace function public.set_member_role(p_chat_id uuid, p_user_id uuid, p_role text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_role not in ('admin', 'member') then raise exception 'invalid role'; end if;
  if not is_chat_admin(p_chat_id) then raise exception 'not allowed'; end if;

  update chat_members set role = p_role
   where chat_id = p_chat_id and user_id = p_user_id and role <> 'owner' and role <> p_role;

  if found then
    perform log_group_event(p_chat_id, case p_role when 'admin' then 'promoted' else 'demoted' end, array[p_user_id]);
  end if;
end;
$$;

-- Name / description / photo edits go through here so they are logged.
create or replace function public.update_group(
  p_chat_id uuid,
  p_name text default null,
  p_description text default null,
  p_avatar_url text default null
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_old chats%rowtype;
begin
  if not is_chat_admin(p_chat_id) then raise exception 'not allowed'; end if;
  select * into v_old from chats where id = p_chat_id and type = 'group';
  if not found then raise exception 'not a group'; end if;

  update chats set
    name        = coalesce(nullif(trim(p_name), ''), name),
    description = coalesce(p_description, description),
    avatar_url  = coalesce(p_avatar_url, avatar_url)
   where id = p_chat_id;

  if p_name is not null and trim(p_name) <> '' and trim(p_name) <> v_old.name then
    perform log_group_event(p_chat_id, 'renamed', '{}', jsonb_build_object('name', trim(p_name)));
  end if;
  if p_avatar_url is not null and p_avatar_url is distinct from v_old.avatar_url then
    perform log_group_event(p_chat_id, 'photo_changed');
  end if;
end;
$$;

-- Edits must be logged, so admins no longer update the row directly.
drop policy if exists "admins update groups" on public.chats;
