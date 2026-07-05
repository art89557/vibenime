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
