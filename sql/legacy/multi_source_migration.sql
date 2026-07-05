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
