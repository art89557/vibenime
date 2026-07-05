-- ============================================================
-- VibeNime 00_core.sql — Video catalog + config + source mapping
-- Run FIRST. Konsolidasi: init + multi_source_migration + admin_rls
--                        + app_config + anime_source_mapping
-- ============================================================

-- VibeNime — Supabase schema initialization
-- Jalankan di Supabase SQL Editor pertama kali setelah create project.

-- ─────────────────────────────────────────────────────────────────────
-- Table: video_sources
-- ─────────────────────────────────────────────────────────────────────
-- Menyimpan mapping anime + episode → video URL.
-- Multiple rows untuk anime yang sama (per episode + per quality).
create table if not exists video_sources (
  id uuid primary key default gen_random_uuid(),
  anilist_id integer not null,
  episode_number integer not null default 1,
  video_url text not null,
  subtitle_url text,
  language text default 'en',
  quality text default '480p',
  source_type text default 'archive_org' check (
    source_type in ('archive_org', 'cloudflare_r2', 'mux', 'youtube', 'manual')
  ),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index untuk fast lookup by anime + episode
create index if not exists idx_video_sources_anilist_episode
  on video_sources (anilist_id, episode_number);

-- ─────────────────────────────────────────────────────────────────────
-- Row Level Security (RLS) — public read, no public write
-- ─────────────────────────────────────────────────────────────────────
alter table video_sources enable row level security;

-- Anyone (anon key) can read
create policy "Anyone can read video sources"
  on video_sources for select
  using (true);

-- Hanya service_role yang bisa insert/update/delete (untuk admin via SQL)
-- Tidak ada policy untuk authenticated/anon → otomatis denied

-- ─────────────────────────────────────────────────────────────────────
-- Helper: trigger update updated_at on row change
-- ─────────────────────────────────────────────────────────────────────
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_video_sources_updated_at on video_sources;
create trigger trg_video_sources_updated_at
  before update on video_sources
  for each row execute function update_updated_at();

-- ─────────────────────────────────────────────────────────────────────
-- Verifikasi
-- ─────────────────────────────────────────────────────────────────────
-- Setelah run, cek di Table Editor — harus ada tabel `video_sources` kosong.
-- Lanjut ke seed.sql untuk insert sample data.

-- VibeNime — Multi-Source Migration
-- Jalankan SETELAH init.sql + admin_rls.sql.
-- Migration ini menambahkan support untuk MULTIPLE video sources per episode
-- dengan priority-based fallback.
--
-- Use case: Episode 1 Spy x Family bisa punya 3 source:
--   priority 1: youtube (Muse Asia)
--   priority 2: archive_org (backup)
--   priority 3: r2 (self-host)
-- Player coba priority 1 dulu; kalau gagal, switch ke 2, dst.

-- ─────────────────────────────────────────────────────────────────────
-- 1. Tambah column priority
-- ─────────────────────────────────────────────────────────────────────
-- Default 100 supaya ada ruang di atas (1-99) untuk source premium.
-- Lower number = higher priority.

alter table video_sources
  add column if not exists priority integer not null default 100;

-- ─────────────────────────────────────────────────────────────────────
-- 2. Drop unique constraint lama (kalau ada)
-- ─────────────────────────────────────────────────────────────────────
-- Sebelum migration ini, sebenarnya tidak ada unique constraint di
-- (anilist_id, episode_number) — tapi pastikan tidak ada constraint
-- yang block multiple rows untuk pasangan tsb.
-- (No-op kalau memang tidak ada.)

-- ─────────────────────────────────────────────────────────────────────
-- 3. Index baru untuk fast priority-ordered query
-- ─────────────────────────────────────────────────────────────────────

drop index if exists idx_video_sources_anilist_episode;

create index if not exists idx_video_sources_lookup
  on video_sources (anilist_id, episode_number, priority);

-- ─────────────────────────────────────────────────────────────────────
-- 4. (Optional) Set priority default untuk seed data existing
-- ─────────────────────────────────────────────────────────────────────
-- Existing rows otomatis dapat priority=100 dari default value.
-- Kalau mau prioritize source tertentu (mis. yang highest quality),
-- update manual:
--
-- update video_sources set priority = 50 where source_type = 'cloudflare_r2';
-- update video_sources set priority = 60 where source_type = 'youtube';
-- update video_sources set priority = 100 where source_type = 'archive_org';
-- update video_sources set priority = 200 where source_type = 'mux';

-- ─────────────────────────────────────────────────────────────────────
-- VERIFY
-- ─────────────────────────────────────────────────────────────────────
-- Cek struktur table:
-- select column_name, data_type, column_default
-- from information_schema.columns
-- where table_name = 'video_sources'
-- order by ordinal_position;
--
-- Test query priority-ordered:
-- select anilist_id, episode_number, source_type, priority
-- from video_sources
-- where anilist_id = 4082 and episode_number = 1
-- order by priority asc;

-- ─────────────────────────────────────────────────────────────────────
-- CONTOH MULTI-SOURCE INSERT
-- ─────────────────────────────────────────────────────────────────────
-- 3 source untuk Spy x Family EP 1 (anilist_id misal 140960):
--
-- insert into video_sources
--   (anilist_id, episode_number, video_url, source_type, quality, priority, notes)
-- values
--   (140960, 1, 'https://youtube.com/watch?v=ABC123', 'youtube',     '1080p',  50, 'Muse Asia EP 1'),
--   (140960, 1, 'https://r2.example/spyx-ep1.mp4',   'cloudflare_r2','720p', 100, 'R2 backup'),
--   (140960, 1, 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8', 'mux', 'auto', 200, 'Sample fallback');

-- VibeNime — Admin RLS Policies
-- Jalankan di Supabase SQL Editor SETELAH init.sql.
-- Policy ini membuka write access untuk authenticated users (admin only).

-- ─────────────────────────────────────────────────────────────────────
-- INSERT — authenticated users only
-- ─────────────────────────────────────────────────────────────────────
drop policy if exists "Authenticated users can insert" on video_sources;
create policy "Authenticated users can insert"
  on video_sources for insert
  with check (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────────────────────────────
-- UPDATE — authenticated users only
-- ─────────────────────────────────────────────────────────────────────
drop policy if exists "Authenticated users can update" on video_sources;
create policy "Authenticated users can update"
  on video_sources for update
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────────────────────────────
-- DELETE — authenticated users only
-- ─────────────────────────────────────────────────────────────────────
drop policy if exists "Authenticated users can delete" on video_sources;
create policy "Authenticated users can delete"
  on video_sources for delete
  using (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────────────────────────────
-- SELECT (read) tetap public — sudah ada di init.sql
-- ─────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────
-- LANGKAH BERIKUTNYA: Buat admin user
-- ─────────────────────────────────────────────────────────────────────
-- Setelah run script ini:
--
-- 1. Pergi ke Authentication → Users di Supabase Dashboard
-- 2. Klik "Add user" → "Create new user"
-- 3. Isi email + password (catat untuk login di app!)
-- 4. Centang "Auto Confirm User"
-- 5. Save
--
-- Login pakai credentials ini di Admin Panel app.

-- VibeNime app_config table
-- ---------------------------------------------------------
-- Simple key-value config buat fitur runtime:
-- • min_version_android — force update kalau current < ini
-- • latest_version_android — recommended (non-blocking upgrade prompt)
-- • update_url — link Play Store / APK download
-- • maintenance_mode — "true" untuk freeze app (planned downtime)
--
-- RLS: read-only untuk anon (semua user bisa cek), write hanya
-- service_role (lewat Supabase dashboard manual).
--
-- Run di Supabase SQL Editor.

create table if not exists public.app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

-- Seed default values
insert into public.app_config (key, value) values
  ('min_version_android', '1.0.0'),
  ('latest_version_android', '1.0.0'),
  ('update_url', 'https://play.google.com/store/apps/details?id=com.vibenime.vibenime'),
  ('maintenance_mode', 'false')
on conflict (key) do nothing;

-- RLS: anon can read
alter table public.app_config enable row level security;

drop policy if exists "app_config_read_all" on public.app_config;
create policy "app_config_read_all"
  on public.app_config for select
  using (true);

-- Insert/update di-block untuk anon (admin pakai service_role di dashboard)
drop policy if exists "app_config_no_write" on public.app_config;
create policy "app_config_no_write"
  on public.app_config for all
  using (false)
  with check (false);

-- VibeNime anime_source_mapping
-- ---------------------------------------------------------
-- Cache mapping AniList anime ID → slug di source site Indonesia
-- (Otakudesu / Kuramanime / Samehadaku). Tujuan: hindari re-fuzzy-match
-- setiap kali user buka detail. Saat fuzzy match resolve sekali, hasilnya
-- cache di tabel ini.
--
-- Untuk admin override manual, lihat admin form screen.
--
-- Run di Supabase SQL Editor.

create table if not exists public.anime_source_mapping (
  anilist_id int not null,
  source text not null,            -- 'otakudesu' | 'kuramanime' | 'samehadaku' | 'gogoanime'
  source_slug text not null,       -- e.g. 'kimetsu-no-yaiba'
  total_episodes int,
  confidence numeric default 1.0,  -- 0-1 untuk fuzzy match score (1.0 = manual override)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (anilist_id, source)
);

create index if not exists idx_anime_source_mapping_anilist
  on public.anime_source_mapping (anilist_id);

-- RLS: read public, write hanya untuk user authenticated (anon read-only).
-- Tujuannya: app bisa cache hasil fuzzy-match, tapi user random tidak bisa
-- pollute data dengan slug salah.
alter table public.anime_source_mapping enable row level security;

drop policy if exists "anime_source_mapping_read_all" on public.anime_source_mapping;
create policy "anime_source_mapping_read_all"
  on public.anime_source_mapping for select
  using (true);

drop policy if exists "anime_source_mapping_authenticated_insert" on public.anime_source_mapping;
create policy "anime_source_mapping_authenticated_insert"
  on public.anime_source_mapping for insert
  with check (auth.uid() is not null);

drop policy if exists "anime_source_mapping_authenticated_update" on public.anime_source_mapping;
create policy "anime_source_mapping_authenticated_update"
  on public.anime_source_mapping for update
  using (auth.uid() is not null);

-- Auto-update `updated_at` saat row di-update
create or replace function set_anime_source_mapping_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_anime_source_mapping_updated_at on public.anime_source_mapping;
create trigger trg_anime_source_mapping_updated_at
  before update on public.anime_source_mapping
  for each row execute function set_anime_source_mapping_updated_at();
