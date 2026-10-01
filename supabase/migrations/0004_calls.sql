-- =====================================================================
-- Sawa Chat — phase 8: 1-to-1 voice & video calls
-- Run in Supabase Dashboard → SQL Editor after 0003.
--
-- The `calls` row is the source of truth for a call's lifecycle; media and
-- WebRTC signaling never touch the database (Realtime Broadcast + P2P).
--
--   ringing ──accept──► accepted ──end──► ended
--      │ decline ► declined   cancel ► cancelled   timeout ► missed
--   (callee already in a call ► busy, set at creation)
-- =====================================================================

-- A call counts as "live" only while plausibly still happening, so a crashed
-- app can't leave someone permanently busy.
create or replace function public.is_in_live_call(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from calls
     where p_user in (caller_id, callee_id)
       and (
         (status = 'ringing' and created_at > now() - interval '60 seconds')
         or (status = 'accepted' and answered_at > now() - interval '4 hours')
       )
  );
$$;

create or replace function public.start_call(p_callee uuid, p_kind text)
returns public.calls
language plpgsql security definer set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_call calls;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('audio', 'video') then raise exception 'invalid kind'; end if;
  if p_callee = v_me then raise exception 'cannot call yourself'; end if;
  if is_blocked_between(v_me, p_callee) then raise exception 'not allowed'; end if;

  insert into calls (chat_id, caller_id, callee_id, kind, status, ended_at)
  values (
    get_or_create_direct_chat(p_callee), v_me, p_callee, p_kind,
    case when is_in_live_call(p_callee) then 'busy' else 'ringing' end,
    case when is_in_live_call(p_callee) then now() end
  )
  returning * into v_call;

  if v_call.status = 'busy' then perform log_call_message(v_call); end if;
  return v_call;
end;
$$;

-- Writes the "📞 Voice call · 2:31" / "Missed call" entry into the chat, once.
create or replace function public.log_call_message(p_call public.calls)
returns void
language sql security definer set search_path = public
as $$
  insert into messages (client_id, chat_id, sender_id, type, media_meta)
  select gen_random_uuid(), p_call.chat_id, p_call.caller_id, 'call',
         jsonb_build_object(
           'call_id', p_call.id,
           'kind', p_call.kind,
           'status', p_call.status,
           'duration_s', coalesce(extract(epoch from (p_call.ended_at - p_call.answered_at))::int, 0)
         )
   where p_call.chat_id is not null;
$$;

revoke execute on function public.log_call_message(public.calls) from public, anon, authenticated;

create or replace function public.update_call_status(p_call_id uuid, p_status text)
returns public.calls
language plpgsql security definer set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_call calls;
begin
  select * into v_call from calls where id = p_call_id for update;
  if not found or v_me not in (v_call.caller_id, v_call.callee_id) then raise exception 'not allowed'; end if;

  -- Allowed transitions, and who may make them.
  if not (
    (v_call.status = 'ringing' and p_status in ('accepted', 'declined') and v_me = v_call.callee_id)
    or (v_call.status = 'ringing' and p_status in ('cancelled', 'missed') and v_me = v_call.caller_id)
    or (v_call.status = 'accepted' and p_status = 'ended')
  ) then
    return v_call; -- Already moved on (e.g. both sides hung up at once): no-op.
  end if;

  update calls set
    status      = p_status,
    answered_at = case when p_status = 'accepted' then now() else answered_at end,
    ended_at    = case when p_status <> 'accepted' then now() else ended_at end
  where id = p_call_id
  returning * into v_call;

  if p_status <> 'accepted' then perform log_call_message(v_call); end if;
  return v_call;
end;
$$;

-- Status changes must go through update_call_status.
drop policy if exists "participants update call" on public.calls;
drop policy if exists "caller creates call" on public.calls;
