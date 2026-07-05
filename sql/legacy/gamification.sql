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
