-- ============================================================
-- VibeNime 01_user.sql — Profiles + roles + gamification
-- Run SETELAH 00_core. Konsolidasi: user_profiles + admin_roles
--                                  + gamification (XP merged ke profiles)
-- ============================================================

-- VibeNime user_profiles
-- ---------------------------------------------------------
-- Dedicated table untuk profile data (bio, banner, avatar, border, privacy).
-- Sebelumnya disimpan di user_metadata JSON yang sulit di-query.
--
-- Run di Supabase SQL Editor.

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  bio text check (char_length(bio) <= 200),
  avatar_url text,
  banner_url text,
  avatar_border text default 'none',
  privacy_show_stats boolean not null default true,
  privacy_show_activity boolean not null default true,
  privacy_show_favorites boolean not null default true,
  privacy_allow_friend_requests boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_profiles_username on public.user_profiles(username);

-- Auto-update updated_at saat row di-modify
create or replace function set_user_profiles_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function set_user_profiles_updated_at();

-- Auto-create row saat user signup via trigger di auth.users
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.user_profiles (user_id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: sync existing users dari user_metadata ke user_profiles
insert into public.user_profiles (user_id, username, avatar_url, banner_url, bio, avatar_border)
select
  id,
  coalesce(raw_user_meta_data->>'username', split_part(email, '@', 1)),
  raw_user_meta_data->>'avatar_url',
  raw_user_meta_data->>'banner_url',
  raw_user_meta_data->>'bio',
  coalesce(raw_user_meta_data->>'avatar_border', 'none')
from auth.users
on conflict (user_id) do nothing;

-- RLS: read public (respect privacy via app-side filter), write hanya self
alter table public.user_profiles enable row level security;

drop policy if exists "profiles_read_all" on public.user_profiles;
create policy "profiles_read_all" on public.user_profiles
  for select using (true);

drop policy if exists "profiles_update_own" on public.user_profiles;
create policy "profiles_update_own" on public.user_profiles
  for update using (auth.uid() = user_id);

drop policy if exists "profiles_insert_own" on public.user_profiles;
create policy "profiles_insert_own" on public.user_profiles
  for insert with check (auth.uid() = user_id);

-- Update RPC get_user_profile untuk return dari user_profiles table
create or replace function get_user_profile(target_id uuid)
returns table (
  id uuid,
  username text,
  avatar_url text,
  banner_url text,
  bio text,
  avatar_border text
) as $$
  select user_id as id, username, avatar_url, banner_url, bio, avatar_border
  from public.user_profiles
  where user_id = target_id;
$$ language sql security definer;

-- VibeNime admin roles + ban system
-- ---------------------------------------------------------
-- Role hierarchy: super_admin > admin > user.
-- Super-admin set MANUAL via Supabase Dashboard untuk security.
-- Super-admin lalu bisa promote user lain ke admin via app.
--
-- Prerequisite: jalan sql/user_profiles.sql DULU.
--
-- Initial super-admin setup (run setelah cek user UUID kamu):
-- UPDATE public.user_profiles SET role = 'super_admin' WHERE user_id = 'YOUR_UUID';

create type user_role as enum ('user', 'admin', 'super_admin');

alter table public.user_profiles
  add column if not exists role user_role not null default 'user',
  add column if not exists banned_at timestamptz,
  add column if not exists banned_reason text,
  add column if not exists banned_by uuid references auth.users(id);

create index if not exists idx_user_profiles_role on public.user_profiles(role);
create index if not exists idx_user_profiles_banned on public.user_profiles(banned_at)
  where banned_at is not null;

-- ─── RPC: set_role (super_admin only) ────────────────────────────────────
create or replace function admin_set_role(target_id uuid, new_role user_role)
returns void as $$
declare
  caller_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role is null or caller_role != 'super_admin' then
    raise exception 'Forbidden: only super_admin can change roles';
  end if;
  update public.user_profiles set role = new_role where user_id = target_id;
end;
$$ language plpgsql security definer;

-- ─── RPC: ban_user (admin atau super_admin) ──────────────────────────────
create or replace function admin_ban_user(target_id uuid, reason text)
returns void as $$
declare
  caller_role user_role;
  target_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  -- Admin biasa tidak bisa ban super_admin atau admin lain
  select role into target_role from public.user_profiles where user_id = target_id;
  if caller_role = 'admin' and target_role in ('admin', 'super_admin') then
    raise exception 'Forbidden: admin cannot ban admin/super_admin';
  end if;
  update public.user_profiles
  set banned_at = now(), banned_reason = reason, banned_by = auth.uid()
  where user_id = target_id;
end;
$$ language plpgsql security definer;

-- ─── RPC: unban_user ─────────────────────────────────────────────────────
create or replace function admin_unban_user(target_id uuid)
returns void as $$
declare caller_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  update public.user_profiles
  set banned_at = null, banned_reason = null, banned_by = null
  where user_id = target_id;
end;
$$ language plpgsql security definer;

-- ─── RPC: dashboard stats ────────────────────────────────────────────────
create or replace function admin_dashboard_stats()
returns table (
  total_users bigint,
  signups_today bigint,
  signups_week bigint,
  active_users_7d bigint,
  total_messages bigint,
  total_friendships bigint,
  banned_users bigint,
  admin_count bigint
) as $$
  select
    (select count(*) from public.user_profiles) as total_users,
    (select count(*) from public.user_profiles
       where created_at > now() - interval '1 day') as signups_today,
    (select count(*) from public.user_profiles
       where created_at > now() - interval '7 days') as signups_week,
    (select count(distinct user_id) from public.activity_events
       where created_at > now() - interval '7 days') as active_users_7d,
    coalesce((select count(*) from public.direct_messages), 0) as total_messages,
    (select count(*) from public.friendships where status = 'accepted') as total_friendships,
    (select count(*) from public.user_profiles where banned_at is not null) as banned_users,
    (select count(*) from public.user_profiles where role in ('admin', 'super_admin')) as admin_count;
$$ language sql security definer;

-- ─── RPC: list_users (admin only, paginated) ─────────────────────────────
create or replace function admin_list_users(
  p_query text default '',
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  user_id uuid,
  email text,
  username text,
  avatar_url text,
  role user_role,
  banned_at timestamptz,
  banned_reason text,
  created_at timestamptz
) as $$
declare caller_role user_role;
begin
  select up.role into caller_role from public.user_profiles up where up.user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  return query
  select up.user_id, u.email, up.username, up.avatar_url, up.role,
         up.banned_at, up.banned_reason, up.created_at
  from public.user_profiles up
  join auth.users u on u.id = up.user_id
  where p_query = '' OR up.username ilike '%' || p_query || '%' OR u.email ilike '%' || p_query || '%'
  order by up.created_at desc
  limit p_limit
  offset p_offset;
end;
$$ language plpgsql security definer;

-- ─── RPC: recent messages (moderation) ───────────────────────────────────
create or replace function admin_recent_messages(p_limit int default 100)
returns table (
  id uuid,
  sender_id uuid,
  sender_username text,
  recipient_id uuid,
  content text,
  created_at timestamptz
) as $$
declare caller_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  return query
  select dm.id, dm.sender_id, up.username, dm.recipient_id, dm.content, dm.created_at
  from public.direct_messages dm
  left join public.user_profiles up on up.user_id = dm.sender_id
  order by dm.created_at desc
  limit p_limit;
end;
$$ language plpgsql security definer;

-- ─── RPC: delete message (admin/super_admin) ─────────────────────────────
create or replace function admin_delete_message(message_id uuid)
returns void as $$
declare caller_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  delete from public.direct_messages where id = message_id;
end;
$$ language plpgsql security definer;

-- VibeNime gamification — XP + Level + Badges
-- ---------------------------------------------------------
-- Reward sistem untuk engagement: tonton episode → XP → level up,
-- unlock badge berdasarkan milestone (100 ep, 10 anime selesai, 10 friends).
--
-- Run setelah activity_events table sudah ada.

create table if not exists public.user_xp (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp int not null default 0,
  level int not null default 1,
  updated_at timestamptz not null default now()
);

create table if not exists public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_code text not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_code)
);

create index if not exists idx_user_badges_user on public.user_badges(user_id);

alter table public.user_xp enable row level security;
alter table public.user_badges enable row level security;

drop policy if exists "xp_read_all" on public.user_xp;
create policy "xp_read_all" on public.user_xp for select using (true);

drop policy if exists "badges_read_all" on public.user_badges;
create policy "badges_read_all" on public.user_badges for select using (true);

-- ─── RPC: add_xp ─────────────────────────────────────────────────────────
-- Level formula: level = floor(sqrt(xp / 100)) + 1
-- Level 1 = 0-99 XP, Level 2 = 100-399 XP, Level 3 = 400-899, etc.
create or replace function add_xp(amount int)
returns int as $$
declare
  new_xp int;
  new_level int;
begin
  insert into public.user_xp (user_id, xp)
  values (auth.uid(), amount)
  on conflict (user_id) do update
    set xp = public.user_xp.xp + amount, updated_at = now()
  returning xp into new_xp;

  new_level := floor(sqrt(new_xp::float / 100)) + 1;
  update public.user_xp set level = new_level where user_id = auth.uid();
  return new_xp;
end;
$$ language plpgsql security definer;

-- ─── RPC: check + award badges ───────────────────────────────────────────
-- Auto-evaluate semua badge criteria untuk user. Idempotent (on conflict do nothing).
create or replace function check_and_award_badges()
returns void as $$
declare uid uuid;
begin
  uid := auth.uid();
  if uid is null then return; end if;

  -- "First Episode" — watch 1 episode
  insert into public.user_badges (user_id, badge_code)
  select uid, 'first_episode'
  where exists (
    select 1 from public.activity_events
    where user_id = uid and type = 'watched_episode'
  )
  on conflict do nothing;

  -- "Binge Watcher" — watch 100 episodes
  insert into public.user_badges (user_id, badge_code)
  select uid, 'binge_watcher'
  where (select count(*) from public.activity_events
         where user_id = uid and type = 'watched_episode') >= 100
  on conflict do nothing;

  -- "Completionist" — finish 10 anime
  insert into public.user_badges (user_id, badge_code)
  select uid, 'completionist'
  where (select count(*) from public.activity_events
         where user_id = uid and type = 'completed_anime') >= 10
  on conflict do nothing;

  -- "Social Butterfly" — 10 friends
  insert into public.user_badges (user_id, badge_code)
  select uid, 'social_butterfly'
  where (select count(*) from public.friendships
         where status = 'accepted' AND (requester_id = uid OR recipient_id = uid)) >= 10
  on conflict do nothing;

  -- "List Builder" — 25 items added to list
  insert into public.user_badges (user_id, badge_code)
  select uid, 'list_builder'
  where (select count(*) from public.activity_events
         where user_id = uid and type = 'added_to_list') >= 25
  on conflict do nothing;
end;
$$ language plpgsql security definer;

-- ============================================================
-- MERGE user_xp → user_profiles (optimisasi: relasi 1:1)
-- ============================================================
alter table public.user_profiles
  add column if not exists xp int not null default 0,
  add column if not exists level int not null default 1;

-- Backfill dari user_xp lama (kalau ada) SEBELUM drop
update public.user_profiles up
set xp = ux.xp, level = ux.level
from public.user_xp ux
where ux.user_id = up.user_id;

-- Override add_xp RPC → target user_profiles (bukan user_xp)
create or replace function add_xp(amount int)
returns int as $$
declare new_xp int; new_level int;
begin
  update public.user_profiles
  set xp = xp + amount
  where user_id = auth.uid()
  returning xp into new_xp;
  if new_xp is null then return 0; end if;
  new_level := floor(sqrt(new_xp::float / 100)) + 1;
  update public.user_profiles set level = new_level where user_id = auth.uid();
  return new_xp;
end;
$$ language plpgsql security definer;

-- Drop tabel user_xp lama (data sudah di-backfill ke user_profiles)
drop table if exists public.user_xp;
