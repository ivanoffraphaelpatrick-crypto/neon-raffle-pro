
-- NEON RAFFLE PRO — Supabase setup
-- Run this whole file in Supabase > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.raffle_settings (
  singleton boolean primary key default true check (singleton),
  title text not null default 'LA TOMBOLA NEON',
  prize text not null default 'Un cadeau surprise !',
  is_open boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.raffle_settings(singleton)
values (true) on conflict (singleton) do nothing;

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.participants (
  id bigint generated always as identity primary key,
  username text not null,
  username_normalized text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.winners (
  id bigint generated always as identity primary key,
  participant_id bigint not null unique references public.participants(id),
  drawn_at timestamptz not null default now()
);

create or replace function public.is_raffle_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists(select 1 from public.admins where user_id = auth.uid());
$$;

alter table public.raffle_settings enable row level security;
alter table public.admins enable row level security;
alter table public.participants enable row level security;
alter table public.winners enable row level security;

drop policy if exists "Public can read raffle settings" on public.raffle_settings;
create policy "Public can read raffle settings" on public.raffle_settings
for select to anon, authenticated using (true);

drop policy if exists "Admins update raffle settings" on public.raffle_settings;
create policy "Admins update raffle settings" on public.raffle_settings
for update to authenticated using (public.is_raffle_admin())
with check (public.is_raffle_admin());

drop policy if exists "Admins read own admin row" on public.admins;
create policy "Admins read own admin row" on public.admins
for select to authenticated using (user_id = auth.uid());

drop policy if exists "Admins read participants" on public.participants;
create policy "Admins read participants" on public.participants
for select to authenticated using (public.is_raffle_admin());

drop policy if exists "Admins delete participants" on public.participants;
create policy "Admins delete participants" on public.participants
for delete to authenticated using (public.is_raffle_admin());

drop policy if exists "Admins read winners" on public.winners;
create policy "Admins read winners" on public.winners
for select to authenticated using (public.is_raffle_admin());

drop policy if exists "Admins delete winners" on public.winners;
create policy "Admins delete winners" on public.winners
for delete to authenticated using (public.is_raffle_admin());

create or replace function public.get_public_raffle_state()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select jsonb_build_object(
    'title', s.title,
    'prize', s.prize,
    'is_open', s.is_open,
    'participant_count', (select count(*) from public.participants)
  )
  from public.raffle_settings s where s.singleton = true;
$$;

create or replace function public.register_raffle_participant(p_username text)
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  v_username text;
  v_id bigint;
begin
  v_username := lower(regexp_replace(trim(coalesce(p_username, '')), '^@+', ''));
  if v_username = '' or length(v_username) > 30 or v_username !~ '^[a-z0-9._]+$' then
    raise exception 'INVALID_USERNAME';
  end if;

  if not (select is_open from public.raffle_settings where singleton = true) then
    raise exception 'RAFFLE_CLOSED';
  end if;

  insert into public.participants(username, username_normalized)
  values ('@' || v_username, v_username)
  returning id into v_id;

  return jsonb_build_object('ticket', v_id, 'username', '@' || v_username);
exception
  when unique_violation then
    raise exception 'USERNAME_ALREADY_REGISTERED';
end;
$$;

create or replace function public.admin_draw_raffle_winner()
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  v_participant public.participants%rowtype;
  v_winner_id bigint;
begin
  if not public.is_raffle_admin() then
    raise exception 'NOT_AUTHORIZED';
  end if;

  perform pg_advisory_xact_lock(7241901);

  select p.* into v_participant
  from public.participants p
  where not exists (
    select 1 from public.winners w where w.participant_id = p.id
  )
  order by random()
  limit 1;

  if not found then
    raise exception 'NO_ELIGIBLE_PARTICIPANTS';
  end if;

  insert into public.winners(participant_id)
  values (v_participant.id)
  returning id into v_winner_id;

  return jsonb_build_object(
    'winner_id', v_winner_id,
    'participant_id', v_participant.id,
    'username', v_participant.username,
    'ticket', v_participant.id,
    'drawn_at', now()
  );
end;
$$;

revoke all on function public.get_public_raffle_state() from public;
grant execute on function public.get_public_raffle_state() to anon, authenticated;
revoke all on function public.register_raffle_participant(text) from public;
grant execute on function public.register_raffle_participant(text) to anon, authenticated;
revoke all on function public.admin_draw_raffle_winner() from public;
grant execute on function public.admin_draw_raffle_winner() to authenticated;

grant usage, select on all sequences in schema public to authenticated;
