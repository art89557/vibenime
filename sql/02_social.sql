-- ============================================================
-- VibeNime 02_social.sql — Friends + DM + activity + discussions
-- Run SETELAH 01_user. Konsolidasi: friendships + direct_messages
--                                  + activity_events + anime_discussions
-- ============================================================

-- VibeNime friendships
-- ---------------------------------------------------------
-- Tabel friendship antar user. Status: pending → accepted (atau blocked).
-- Pair unique — tidak bisa duplicate request.

create type friendship_status as enum ('pending', 'accepted', 'blocked');

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  constraint no_self_friend check (requester_id != recipient_id),
  constraint unique_pair unique (requester_id, recipient_id)
);

create index if not exists idx_friendships_recipient
  on public.friendships(recipient_id, status);
create index if not exists idx_friendships_requester
  on public.friendships(requester_id, status);

alter table public.friendships enable row level security;

drop policy if exists "friendships_read_own" on public.friendships;
create policy "friendships_read_own" on public.friendships for select
  using (auth.uid() = requester_id OR auth.uid() = recipient_id);

drop policy if exists "friendships_insert_own_request" on public.friendships;
create policy "friendships_insert_own_request" on public.friendships for insert
  with check (auth.uid() = requester_id);

drop policy if exists "friendships_update_as_recipient" on public.friendships;
create policy "friendships_update_as_recipient" on public.friendships for update
  using (auth.uid() = recipient_id OR auth.uid() = requester_id);

drop policy if exists "friendships_delete_own" on public.friendships;
create policy "friendships_delete_own" on public.friendships for delete
  using (auth.uid() = requester_id OR auth.uid() = recipient_id);

-- Realtime: enable supaya client subscribe perubahan friendship live
alter publication supabase_realtime add table public.friendships;

-- ─── Search users RPC ─────────────────────────────────────────────────────
-- auth.users tidak boleh diakses RLS langsung dari client.
-- Pakai SQL function `security definer` untuk search by username.

create or replace function search_users_by_username(query text)
returns table (id uuid, username text, avatar_url text, email text) as $$
  select u.id,
         coalesce(u.raw_user_meta_data->>'username', split_part(u.email, '@', 1)) as username,
         u.raw_user_meta_data->>'avatar_url' as avatar_url,
         u.email as email
  from auth.users u
  where (u.raw_user_meta_data->>'username') ilike '%' || query || '%'
     OR u.email ilike '%' || query || '%'
  limit 20;
$$ language sql security definer;

-- Function untuk resolve user profile by ID (untuk Friend list / DM partner)
create or replace function get_user_profile(target_id uuid)
returns table (
  id uuid,
  username text,
  avatar_url text,
  banner_url text,
  bio text,
  avatar_border text
) as $$
  select u.id,
         coalesce(u.raw_user_meta_data->>'username', split_part(u.email, '@', 1)) as username,
         u.raw_user_meta_data->>'avatar_url' as avatar_url,
         u.raw_user_meta_data->>'banner_url' as banner_url,
         u.raw_user_meta_data->>'bio' as bio,
         u.raw_user_meta_data->>'avatar_border' as avatar_border
  from auth.users u
  where u.id = target_id;
$$ language sql security definer;

-- VibeNime direct_messages
-- ---------------------------------------------------------
-- 1-on-1 chat antar friend. Realtime via Supabase publication.

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint dm_no_self check (sender_id != recipient_id)
);

create index if not exists idx_dm_conversation
  on public.direct_messages(
    least(sender_id, recipient_id),
    greatest(sender_id, recipient_id),
    created_at desc
  );

alter table public.direct_messages enable row level security;

-- Read: hanya sender atau recipient — DAN harus accepted friend.
drop policy if exists "dm_read_own" on public.direct_messages;
create policy "dm_read_own" on public.direct_messages for select
  using (
    (auth.uid() = sender_id OR auth.uid() = recipient_id)
    AND exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
      AND (
        (f.requester_id = auth.uid()
         AND f.recipient_id = (
           case when direct_messages.sender_id = auth.uid()
                then direct_messages.recipient_id
                else direct_messages.sender_id end))
        OR (f.recipient_id = auth.uid()
         AND f.requester_id = (
           case when direct_messages.sender_id = auth.uid()
                then direct_messages.recipient_id
                else direct_messages.sender_id end))
      )
    )
  );

-- Insert: harus sender = self AND friend with recipient.
drop policy if exists "dm_send_if_friend" on public.direct_messages;
create policy "dm_send_if_friend" on public.direct_messages for insert
  with check (
    auth.uid() = sender_id
    AND exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
      AND (
        (f.requester_id = auth.uid() AND f.recipient_id = direct_messages.recipient_id)
        OR (f.recipient_id = auth.uid() AND f.requester_id = direct_messages.recipient_id)
      )
    )
  );

-- Update: hanya recipient yang boleh set read_at.
drop policy if exists "dm_mark_read_as_recipient" on public.direct_messages;
create policy "dm_mark_read_as_recipient" on public.direct_messages for update
  using (auth.uid() = recipient_id);

-- Realtime channel untuk DM live chat
alter publication supabase_realtime add table public.direct_messages;

-- VibeNime activity_events
-- ---------------------------------------------------------
-- Log aktivitas user — episode ditonton, anime di-add ke list, completed.
-- Friend lihat aktivitas masing-masing di feed.

create type activity_event_type as enum (
  'watched_episode',
  'added_to_list',
  'completed_anime',
  'favorited'
);

create table if not exists public.activity_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type activity_event_type not null,
  anime_id int not null,
  anime_title text not null,
  anime_cover text,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_activity_user_time
  on public.activity_events(user_id, created_at desc);

create index if not exists idx_activity_time
  on public.activity_events(created_at desc);

alter table public.activity_events enable row level security;

-- User bisa baca aktivitas SEMUA friend (status accepted) + diri sendiri.
-- Privacy: kalau target user set privacy.show_activity=false di metadata,
-- filter di app side (Riverpod provider), bukan di SQL.
drop policy if exists "activity_read_friend" on public.activity_events;
create policy "activity_read_friend" on public.activity_events for select
  using (
    auth.uid() = user_id
    OR exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
      AND (
        (f.requester_id = auth.uid() AND f.recipient_id = activity_events.user_id)
        OR (f.recipient_id = auth.uid() AND f.requester_id = activity_events.user_id)
      )
    )
  );

drop policy if exists "activity_insert_own" on public.activity_events;
create policy "activity_insert_own" on public.activity_events for insert
  with check (auth.uid() = user_id);

-- Realtime: friend lihat aktivitas baru live di feed Home.
alter publication supabase_realtime add table public.activity_events;

-- ─── Cleanup function (run weekly via cron) ───────────────────────────────
-- Purge event >30 hari supaya tabel tidak bloat.
create or replace function purge_old_activity_events()
returns void as $$
  delete from public.activity_events
  where created_at < now() - interval '30 days';
$$ language sql security definer;

-- VibeNime — Anime Discussions Schema
-- Run di Supabase SQL Editor untuk enable feature "Diskusi" di Detail screen.
-- Butuh: init.sql + admin_rls.sql + watch_party.sql sudah di-apply.

-- ─────────────────────────────────────────────────────────────────────
-- 1. Tabel: anime_discussions
-- ─────────────────────────────────────────────────────────────────────
create table if not exists anime_discussions (
  id uuid primary key default gen_random_uuid(),
  anime_id integer not null,
  user_id uuid references auth.users(id) on delete cascade,
  username text not null,
  content text not null check (length(content) between 1 and 1000),
  created_at timestamptz default now()
);

-- Index untuk fast lookup per anime, sorted by latest first
create index if not exists idx_disc_anime_time
  on anime_discussions (anime_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────
-- 2. Row Level Security (RLS)
-- ─────────────────────────────────────────────────────────────────────
alter table anime_discussions enable row level security;

drop policy if exists "Anyone can read discussions" on anime_discussions;
create policy "Anyone can read discussions"
  on anime_discussions for select
  using (true);

drop policy if exists "Authenticated can post discussion" on anime_discussions;
create policy "Authenticated can post discussion"
  on anime_discussions for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "User can delete own discussion" on anime_discussions;
create policy "User can delete own discussion"
  on anime_discussions for delete
  to authenticated
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- 3. REPLICA IDENTITY FULL — required untuk DELETE event di stream filter.
--
-- Default REPLICA IDENTITY DEFAULT cuma kirim PK (id) di OLD record saat
-- DELETE. Akibatnya, client stream `eq('anime_id', X)` tidak bisa match
-- DELETE event (anime_id tidak ada di OLD). Akibatnya, message yang dihapus
-- tidak hilang dari UI sampai user re-subscribe.
--
-- Dengan FULL, OLD record berisi semua kolom → filter bisa match → UI live.
-- ─────────────────────────────────────────────────────────────────────
alter table anime_discussions replica identity full;

-- ─────────────────────────────────────────────────────────────────────
-- 4. Enable Realtime publication
-- ─────────────────────────────────────────────────────────────────────
do $$
begin
  begin
    alter publication supabase_realtime add table anime_discussions;
  exception when duplicate_object then null;
  end;
end $$;

-- ─────────────────────────────────────────────────────────────────────
-- VERIFIKASI
-- ─────────────────────────────────────────────────────────────────────
-- select count(*) from pg_policies where tablename = 'anime_discussions';
-- → 3
