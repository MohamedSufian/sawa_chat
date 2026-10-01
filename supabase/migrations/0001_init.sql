-- =====================================================================
-- Sawa Chat — initial schema
-- Run once in Supabase Dashboard → SQL Editor (or `supabase db push`).
-- =====================================================================

create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  phone         text not null unique,
  username      text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name  text not null check (char_length(display_name) between 1 and 40),
  bio           text check (char_length(bio) <= 140),
  avatar_url    text,
  last_seen_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index profiles_username_trgm on public.profiles using gin (username gin_trgm_ops);
create index profiles_display_name_trgm on public.profiles using gin (display_name gin_trgm_ops);

create table public.chats (
  id               uuid primary key default gen_random_uuid(),
  type             text not null check (type in ('direct', 'group')),
  name             text check (char_length(name) <= 50),
  description      text check (char_length(description) <= 200),
  avatar_url       text,
  -- "<smaller uuid>_<bigger uuid>" for direct chats, prevents duplicates.
  direct_key       text unique,
  created_by       uuid references public.profiles (id) on delete set null,
  last_message_id  uuid,
  last_message_at  timestamptz,
  created_at       timestamptz not null default now(),
  constraint chats_direct_key_check check ((type = 'direct') = (direct_key is not null)),
  constraint chats_group_name_check check (type = 'direct' or name is not null)
);

create table public.chat_members (
  chat_id            uuid not null references public.chats (id) on delete cascade,
  user_id            uuid not null references public.profiles (id) on delete cascade,
  role               text not null default 'member' check (role in ('owner', 'admin', 'member')),
  joined_at          timestamptz not null default now(),
  last_delivered_at  timestamptz not null default now(),
  last_read_at       timestamptz not null default now(),
  muted              boolean not null default false,
  primary key (chat_id, user_id)
);

create index chat_members_user_idx on public.chat_members (user_id);

create table public.messages (
  id                    uuid primary key default gen_random_uuid(),
  -- Generated on the device; makes retries idempotent.
  client_id             uuid not null unique,
  chat_id               uuid not null references public.chats (id) on delete cascade,
  sender_id             uuid references public.profiles (id) on delete set null,
  type                  text not null check (type in ('text', 'image', 'voice', 'system', 'call')),
  content               text check (char_length(content) <= 4000),
  media_path            text,
  -- image: {width, height} · voice: {duration_ms, waveform: [..]} · call: {call_id, kind, status, duration_s}
  media_meta            jsonb,
  reply_to_id           uuid references public.messages (id) on delete set null,
  deleted_for_everyone  boolean not null default false,
  edited_at             timestamptz,
  created_at            timestamptz not null default now()
);

create index messages_chat_created_idx on public.messages (chat_id, created_at desc);

alter table public.chats
  add constraint chats_last_message_fk
  foreign key (last_message_id) references public.messages (id) on delete set null;

create table public.hidden_messages (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  message_id  uuid not null references public.messages (id) on delete cascade,
  primary key (user_id, message_id)
);

create table public.calls (
  id           uuid primary key default gen_random_uuid(),
  chat_id      uuid references public.chats (id) on delete set null,
  caller_id    uuid not null references public.profiles (id) on delete cascade,
  callee_id    uuid not null references public.profiles (id) on delete cascade,
  kind         text not null check (kind in ('audio', 'video')),
  status       text not null default 'ringing'
               check (status in ('ringing', 'accepted', 'declined', 'missed', 'busy', 'cancelled', 'ended')),
  created_at   timestamptz not null default now(),
  answered_at  timestamptz,
  ended_at     timestamptz
);

create index calls_caller_idx on public.calls (caller_id, created_at desc);
create index calls_callee_idx on public.calls (callee_id, created_at desc);

create table public.device_tokens (
  token       text primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  platform    text not null check (platform in ('android', 'ios')),
  locale      text not null default 'en',
  updated_at  timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id);

create table public.blocks (
  blocker_id  uuid not null references public.profiles (id) on delete cascade,
  blocked_id  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ---------------------------------------------------------------------
-- Helpers (security definer avoids RLS recursion on chat_members)
-- ---------------------------------------------------------------------

create or replace function public.is_chat_member(p_chat_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from chat_members where chat_id = p_chat_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_chat_admin(p_chat_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from chat_members
    where chat_id = p_chat_id and user_id = auth.uid() and role in ('owner', 'admin')
  );
$$;

create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from blocks
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  );
$$;

-- ---------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- The phone always comes from the verified auth user, never from the client.
create or replace function public.profiles_set_phone()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  select '+' || ltrim(phone, '+') into new.phone from auth.users where id = new.id;
  return new;
end;
$$;

create trigger profiles_set_phone before insert or update of phone on public.profiles
  for each row execute function public.profiles_set_phone();

create or replace function public.on_message_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update chats
     set last_message_id = new.id,
         last_message_at = new.created_at
   where id = new.chat_id;

  -- Sending a message implies the sender has read everything before it.
  if new.sender_id is not null then
    update chat_members
       set last_read_at = greatest(last_read_at, new.created_at),
           last_delivered_at = greatest(last_delivered_at, new.created_at)
     where chat_id = new.chat_id and user_id = new.sender_id;
  end if;

  return new;
end;
$$;

create trigger messages_after_insert after insert on public.messages
  for each row execute function public.on_message_inserted();

-- ---------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------

create or replace function public.get_or_create_direct_chat(p_other_user uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_key  text;
  v_chat uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_other_user = v_me then raise exception 'cannot chat with yourself'; end if;
  if not exists (select 1 from profiles where id = p_other_user) then
    raise exception 'user not found';
  end if;

  v_key := least(v_me::text, p_other_user::text) || '_' || greatest(v_me::text, p_other_user::text);

  select id into v_chat from chats where direct_key = v_key;
  if v_chat is not null then return v_chat; end if;

  insert into chats (type, direct_key, created_by)
  values ('direct', v_key, v_me)
  on conflict (direct_key) do nothing
  returning id into v_chat;

  if v_chat is null then
    select id into v_chat from chats where direct_key = v_key;
    return v_chat;
  end if;

  insert into chat_members (chat_id, user_id, role)
  values (v_chat, v_me, 'member'), (v_chat, p_other_user, 'member');

  return v_chat;
end;
$$;

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
  v_me   uuid := auth.uid();
  v_chat uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  insert into chats (type, name, avatar_url, description, created_by)
  values ('group', p_name, p_avatar_url, p_description, v_me)
  returning id into v_chat;

  insert into chat_members (chat_id, user_id, role) values (v_chat, v_me, 'owner');

  insert into chat_members (chat_id, user_id, role)
  select v_chat, m, 'member'
    from unnest(p_member_ids) as m
   where m <> v_me and exists (select 1 from profiles where id = m)
  on conflict do nothing;

  return v_chat;
end;
$$;

create or replace function public.add_group_members(p_chat_id uuid, p_member_ids uuid[])
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not is_chat_admin(p_chat_id) then raise exception 'not allowed'; end if;

  insert into chat_members (chat_id, user_id, role)
  select p_chat_id, m, 'member'
    from unnest(p_member_ids) as m
   where exists (select 1 from profiles where id = m)
  on conflict do nothing;
end;
$$;

create or replace function public.remove_group_member(p_chat_id uuid, p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_target_role text;
begin
  select role into v_target_role from chat_members where chat_id = p_chat_id and user_id = p_user_id;
  if v_target_role is null then return; end if;

  if p_user_id <> auth.uid() then
    if not is_chat_admin(p_chat_id) or v_target_role = 'owner' then
      raise exception 'not allowed';
    end if;
  end if;

  delete from chat_members where chat_id = p_chat_id and user_id = p_user_id;

  -- If the owner left, promote the oldest remaining member.
  if v_target_role = 'owner' then
    update chat_members set role = 'owner'
     where (chat_id, user_id) = (
       select chat_id, user_id from chat_members
        where chat_id = p_chat_id order by joined_at limit 1
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
   where chat_id = p_chat_id and user_id = p_user_id and role <> 'owner';
end;
$$;

create or replace function public.mark_chat_delivered(p_chat_id uuid)
returns void
language sql security definer set search_path = public
as $$
  update chat_members set last_delivered_at = now()
   where chat_id = p_chat_id and user_id = auth.uid();
$$;

create or replace function public.mark_chat_read(p_chat_id uuid)
returns void
language sql security definer set search_path = public
as $$
  update chat_members set last_read_at = now(), last_delivered_at = now()
   where chat_id = p_chat_id and user_id = auth.uid();
$$;

create or replace function public.set_chat_muted(p_chat_id uuid, p_muted boolean)
returns void
language sql security definer set search_path = public
as $$
  update chat_members set muted = p_muted
   where chat_id = p_chat_id and user_id = auth.uid();
$$;

create or replace function public.delete_message_for_everyone(p_message_id uuid)
returns void
language sql security definer set search_path = public
as $$
  update messages
     set deleted_for_everyone = true, content = null, media_path = null, media_meta = null
   where id = p_message_id and sender_id = auth.uid();
$$;

create or replace function public.search_users(p_query text, p_limit int default 20)
returns setof public.profiles
language sql stable security definer set search_path = public
as $$
  select p.*
    from profiles p
   where p.id <> auth.uid()
     and not is_blocked_between(p.id, auth.uid())
     and (
       p.username ilike lower(trim(p_query)) || '%'
       or p.display_name ilike '%' || trim(p_query) || '%'
       or p.phone = '+' || regexp_replace(p_query, '[^0-9]', '', 'g')
     )
   order by (p.username = lower(trim(p_query))) desc, similarity(p.display_name, p_query) desc
   limit least(p_limit, 50);
$$;

create or replace function public.is_username_available(p_username text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select not exists (
    select 1 from profiles where username = lower(p_username) and id <> auth.uid()
  );
$$;

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------

alter table public.profiles        enable row level security;
alter table public.chats           enable row level security;
alter table public.chat_members    enable row level security;
alter table public.messages        enable row level security;
alter table public.hidden_messages enable row level security;
alter table public.calls           enable row level security;
alter table public.device_tokens   enable row level security;
alter table public.blocks          enable row level security;

-- profiles
create policy "profiles readable by signed-in users" on public.profiles
  for select to authenticated using (true);
create policy "insert own profile" on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy "update own profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- chats (created only through RPCs)
create policy "members read chats" on public.chats
  for select to authenticated using (is_chat_member(id));
create policy "admins update groups" on public.chats
  for update to authenticated
  using (type = 'group' and is_chat_admin(id))
  with check (type = 'group' and is_chat_admin(id));

-- chat_members (writes through RPCs)
create policy "members read membership" on public.chat_members
  for select to authenticated using (is_chat_member(chat_id));

-- messages
create policy "members read messages" on public.messages
  for select to authenticated
  using (
    is_chat_member(chat_id)
    and not exists (
      select 1 from hidden_messages h where h.message_id = messages.id and h.user_id = auth.uid()
    )
  );
create policy "members send messages" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and type <> 'system'
    and is_chat_member(chat_id)
    and not exists (
      select 1 from chats c join chat_members m on m.chat_id = c.id
       where c.id = messages.chat_id and c.type = 'direct'
         and m.user_id <> auth.uid() and is_blocked_between(m.user_id, auth.uid())
    )
  );
create policy "senders edit own text" on public.messages
  for update to authenticated
  using (sender_id = auth.uid() and type = 'text' and not deleted_for_everyone)
  with check (sender_id = auth.uid());

-- hidden_messages
create policy "own hidden messages" on public.hidden_messages
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- calls
create policy "participants read calls" on public.calls
  for select to authenticated using (auth.uid() in (caller_id, callee_id));
create policy "caller creates call" on public.calls
  for insert to authenticated
  with check (caller_id = auth.uid() and not is_blocked_between(caller_id, callee_id));
create policy "participants update call" on public.calls
  for update to authenticated
  using (auth.uid() in (caller_id, callee_id))
  with check (auth.uid() in (caller_id, callee_id));

-- device_tokens
create policy "own device tokens" on public.device_tokens
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- blocks
create policy "own blocks" on public.blocks
  for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- ---------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.chats;
alter publication supabase_realtime add table public.chat_members;
alter publication supabase_realtime add table public.calls;
alter publication supabase_realtime add table public.profiles;

-- ---------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('chat-media', 'chat-media', false, 20971520,
   array['image/jpeg', 'image/png', 'image/webp', 'audio/mp4', 'audio/aac', 'audio/m4a', 'audio/mpeg'])
on conflict (id) do nothing;

-- avatars/<user_id>/...   or   avatars/groups/<chat_id>/...
create policy "avatars public read" on storage.objects
  for select using (bucket_id = 'avatars');
create policy "avatars own write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars' and (
      (storage.foldername(name))[1] = auth.uid()::text
      or ((storage.foldername(name))[1] = 'groups'
          and public.is_chat_admin(((storage.foldername(name))[2])::uuid))
    )
  );
create policy "avatars own delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- chat-media/<chat_id>/<user_id>/<file>
create policy "chat media members read" on storage.objects
  for select to authenticated
  using (bucket_id = 'chat-media' and public.is_chat_member(((storage.foldername(name))[1])::uuid));
create policy "chat media members upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and public.is_chat_member(((storage.foldername(name))[1])::uuid)
    and (storage.foldername(name))[2] = auth.uid()::text
  );
