-- ============================================================
-- VibeNime 07_crash_logs.sql — Crash / error reporting (observability)
-- Run setelah 01_user.sql (butuh auth.users untuk user_id opsional).
-- ============================================================
-- Pengganti Sentry (dihapus karena incompat NDK). App kirim uncaught error
-- (FlutterError/PlatformDispatcher/Zone) ke tabel ini secara best-effort
-- (hanya di build non-debug, rate-limited) → tim bisa lihat crash user nyata
-- tanpa SDK pihak ketiga.

-- ─────────────────────────────────────────────────────────────────────
-- Table: crash_logs
-- ─────────────────────────────────────────────────────────────────────
create table if not exists crash_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null, -- null = guest
  context text,           -- 'FlutterError' / 'PlatformDispatcher' / 'Zone' / dll
  error text not null,
  stack text,
  platform text,          -- 'android' / 'ios' / 'web' / dll
  app_version text,
  created_at timestamptz not null default now()
);

create index if not exists idx_crash_logs_recent
  on crash_logs (created_at desc);

-- ─────────────────────────────────────────────────────────────────────
-- RLS — siapa pun (anon/authenticated) boleh INSERT laporan crash (crash
-- bisa terjadi saat guest / belum login). Hanya admin yang boleh BACA.
-- ─────────────────────────────────────────────────────────────────────
alter table crash_logs enable row level security;

create policy "Anyone can insert crash logs"
  on crash_logs for insert
  to anon, authenticated
  with check (true);

create policy "Admin can read crash logs"
  on crash_logs for select
  to authenticated
  using (
    exists (
      select 1 from public.user_profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'super_admin')
    )
  );
