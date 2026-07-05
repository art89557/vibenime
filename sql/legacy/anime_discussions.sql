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
