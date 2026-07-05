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
