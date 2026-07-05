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
