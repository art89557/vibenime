-- ============================================================
-- VibeNime 08_favorites.sql — Sinkron My List / favorit (cloud)
-- Run setelah 01_user.sql (butuh auth.users untuk user_id).
-- ============================================================
-- Favorit awalnya pure-lokal (Hive). Tabel ini bikin My List nyambung lintas
-- device saat login (melengkapi 06_watch_history). App sinkron dua-arah dgn
-- last-write-wins by updated_at + propagasi hapus via lastSyncAt (tanpa
-- tombstone). Guest/offline tetap jalan lokal.

-- ─────────────────────────────────────────────────────────────────────
-- Table: user_favorites — PK (user_id, anime_id) → upsert-friendly.
-- ─────────────────────────────────────────────────────────────────────
create table if not exists user_favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  anime_id integer not null,
  title text not null default '',
  cover_image text not null default '',
  status text not null default 'PLANNING',   -- PLANNING / WATCHING / COMPLETED
  total_episodes integer,
  added_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, anime_id)
);

create index if not exists idx_user_favorites_recent
  on user_favorites (user_id, updated_at desc);

-- ─────────────────────────────────────────────────────────────────────
-- RLS — tiap user hanya CRUD row miliknya (user_id = auth.uid()).
-- ─────────────────────────────────────────────────────────────────────
alter table user_favorites enable row level security;

create policy "Users can read own favorites"
  on user_favorites for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can insert own favorites"
  on user_favorites for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Users can update own favorites"
  on user_favorites for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete own favorites"
  on user_favorites for delete
  to authenticated
  using (user_id = auth.uid());
