-- ============================================================
-- VibeNime 05_reports.sql — Laporan episode rusak (observability)
-- Run setelah 01_user.sql (butuh referensi auth.users untuk reporter).
-- ============================================================
-- Dipakai tombol "Laporkan episode rusak" di player → tim tahu source mana
-- yang mati / mapping episode salah, tanpa nunggu user komplain manual.

-- ─────────────────────────────────────────────────────────────────────
-- Table: episode_reports
-- ─────────────────────────────────────────────────────────────────────
create table if not exists episode_reports (
  id uuid primary key default gen_random_uuid(),
  anilist_id integer not null,
  episode_number integer not null default 1,
  anime_title text,
  source_id text,                 -- 'otakudesu' / 'samehadaku' / 'mux_sample' / dll
  reason text,                    -- 'tidak_main' / 'salah_episode' / 'lainnya'
  reporter_id uuid references auth.users (id) on delete set null,
  resolved boolean not null default false,
  created_at timestamptz default now()
);

create index if not exists idx_episode_reports_anime
  on episode_reports (anilist_id, episode_number);
create index if not exists idx_episode_reports_open
  on episode_reports (resolved, created_at desc);

-- ─────────────────────────────────────────────────────────────────────
-- RLS — authenticated bisa insert (lapor), hanya admin yang baca/update
-- ─────────────────────────────────────────────────────────────────────
alter table episode_reports enable row level security;

-- Siapa pun yang login boleh kirim laporan.
create policy "Authenticated can insert reports"
  on episode_reports for insert
  to authenticated
  with check (true);

-- User boleh lihat laporannya sendiri.
create policy "Reporter can read own reports"
  on episode_reports for select
  to authenticated
  using (reporter_id = auth.uid());

-- Admin/super_admin boleh baca + update semua (moderasi).
create policy "Admin can read all reports"
  on episode_reports for select
  to authenticated
  using (
    exists (
      select 1 from public.user_profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'super_admin')
    )
  );

create policy "Admin can update reports"
  on episode_reports for update
  to authenticated
  using (
    exists (
      select 1 from public.user_profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'super_admin')
    )
  );
