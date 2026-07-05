-- ============================================================
-- VibeNime 06_watch_history.sql — Sinkron progress nonton (cloud)
-- Run setelah 01_user.sql (butuh auth.users untuk user_id).
-- ============================================================
-- History/posisi tonton awalnya lokal (Hive). Tabel ini bikin progress
-- nyambung lintas device saat login. App push/pull + merge last-write-wins
-- by watched_at. Guest/offline tetap jalan lokal (graceful).

-- ─────────────────────────────────────────────────────────────────────
-- Table: watch_history
-- PK (user_id, anime_id, episode_id) → upsert-friendly (1 row per episode).
-- ─────────────────────────────────────────────────────────────────────
create table if not exists watch_history (
  user_id uuid not null references auth.users (id) on delete cascade,
  anime_id integer not null,
  episode_id text not null,
  episode_number integer not null default 1,
  position_seconds integer not null default 0,
  duration_seconds integer,
  watched_at timestamptz not null default now(),
  primary key (user_id, anime_id, episode_id)
);

-- Ambil history user urut terbaru (Riwayat / Continue Watching).
create index if not exists idx_watch_history_user_recent
  on watch_history (user_id, watched_at desc);

-- ─────────────────────────────────────────────────────────────────────
-- RLS — tiap user hanya CRUD row miliknya (user_id = auth.uid()).
-- ─────────────────────────────────────────────────────────────────────
alter table watch_history enable row level security;

create policy "Users can read own watch history"
  on watch_history for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can insert own watch history"
  on watch_history for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Users can update own watch history"
  on watch_history for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete own watch history"
  on watch_history for delete
  to authenticated
  using (user_id = auth.uid());
