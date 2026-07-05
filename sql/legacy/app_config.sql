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
