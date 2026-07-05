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
