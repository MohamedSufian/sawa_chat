-- =====================================================================
-- Sawa Chat — phase 3: unread counts, delivery receipts, last seen
-- Run in Supabase Dashboard → SQL Editor after 0001_init.sql.
-- =====================================================================

-- Computed column: PostgREST exposes it as `unread_count` on chats
-- (select=*,unread_count). Runs as the caller, so RLS still applies.
create or replace function public.unread_count(c public.chats)
returns integer
language sql stable set search_path = public
as $$
  select count(*)::int
    from messages m
    join chat_members me on me.chat_id = m.chat_id and me.user_id = auth.uid()
   where m.chat_id = c.id
     and m.created_at > me.last_read_at
     and m.sender_id is distinct from auth.uid()
     and m.type <> 'system';
$$;

-- Called whenever the app is in the foreground and sees new messages:
-- marks every chat with newer messages as delivered to me in one statement.
create or replace function public.mark_all_delivered()
returns void
language sql security definer set search_path = public
as $$
  update chat_members cm
     set last_delivered_at = now()
    from chats c
   where c.id = cm.chat_id
     and cm.user_id = auth.uid()
     and c.last_message_at > cm.last_delivered_at;
$$;

-- Server clock, so "last seen" doesn't depend on the device's time.
create or replace function public.touch_last_seen()
returns void
language sql security definer set search_path = public
as $$
  update profiles set last_seen_at = now() where id = auth.uid();
$$;
