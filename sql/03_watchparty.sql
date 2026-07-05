-- ============================================================
-- VibeNime 03_watchparty.sql — Watch party + chat (RLS fix folded)
-- Run SETELAH 01_user. Konsolidasi: watch_party + watch_party_rls_fix
-- ============================================================

-- VibeNime — Watch Party Schema
-- Jalankan di Supabase SQL Editor untuk enable real-time watch party feature.
-- Butuh: init.sql + admin_rls.sql sudah di-apply.

-- ─────────────────────────────────────────────────────────────────────
-- 1. Tabel: watch_parties (active sessions)
-- ─────────────────────────────────────────────────────────────────────
create table if not exists watch_parties (
  id uuid primary key default gen_random_uuid(),
  host_user_id uuid references auth.users(id) on delete cascade,
  host_username text not null,
  anime_id integer not null,
  episode_number integer not null default 1,
  current_position_seconds integer default 0,
  is_playing boolean default true,
  is_active boolean default true,
  participant_count integer default 1,
  started_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index untuk fast lookup active party per anime
create index if not exists idx_party_active
  on watch_parties (is_active, anime_id);

-- ─────────────────────────────────────────────────────────────────────
-- 2. Tabel: chat_messages
-- ─────────────────────────────────────────────────────────────────────
create table if not exists chat_messages (
  id uuid primary key default gen_random_uuid(),
  party_id uuid references watch_parties(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  username text not null,
  message text,
  type text default 'text' check (type in ('text', 'gift', 'system')),
  created_at timestamptz default now()
);

create index if not exists idx_chat_party
  on chat_messages (party_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────
-- 3. Trigger: auto-update updated_at di watch_parties
-- ─────────────────────────────────────────────────────────────────────
create or replace function update_party_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_party_updated_at on watch_parties;
create trigger trg_party_updated_at
  before update on watch_parties
  for each row execute function update_party_updated_at();

-- ─────────────────────────────────────────────────────────────────────
-- 4. Row Level Security (RLS)
-- ─────────────────────────────────────────────────────────────────────
alter table watch_parties enable row level security;
alter table chat_messages enable row level security;

-- watch_parties policies
drop policy if exists "Anyone can read active parties" on watch_parties;
create policy "Anyone can read active parties"
  on watch_parties for select using (is_active = true);

-- Host tetap bisa SELECT row sendiri walaupun is_active=false. Tanpa policy
-- ini, UPDATE `is_active=false` error di RETURNING (RLS reject post-update).
drop policy if exists "Host can read own party" on watch_parties;
create policy "Host can read own party"
  on watch_parties for select
  to authenticated
  using (auth.uid() = host_user_id);

drop policy if exists "Authenticated can create parties" on watch_parties;
create policy "Authenticated can create parties"
  on watch_parties for insert
  to authenticated
  with check (auth.uid() = host_user_id);

-- Update only `using` (find row). `with check` lama redundan dan bisa
-- conflict dengan trigger `update_party_updated_at` yang modify NEW row.
drop policy if exists "Host can update own party" on watch_parties;
create policy "Host can update own party"
  on watch_parties for update
  to authenticated
  using (auth.uid() = host_user_id);

drop policy if exists "Host can delete own party" on watch_parties;
create policy "Host can delete own party"
  on watch_parties for delete
  to authenticated
  using (auth.uid() = host_user_id);

-- chat_messages policies
drop policy if exists "Anyone can read chat" on chat_messages;
create policy "Anyone can read chat"
  on chat_messages for select using (true);

drop policy if exists "Authenticated can post chat" on chat_messages;
create policy "Authenticated can post chat"
  on chat_messages for insert
  with check (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────────────────────────────
-- 5. Enable Realtime publication
-- ─────────────────────────────────────────────────────────────────────
-- Supabase Realtime perlu publication subscription untuk tabel target.
-- Kalau tabel sudah added before, ALTER PUBLICATION akan error gracefully.

do $$
begin
  begin
    alter publication supabase_realtime add table watch_parties;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table chat_messages;
  exception when duplicate_object then null;
  end;
end $$;

-- ─────────────────────────────────────────────────────────────────────
-- VERIFIKASI
-- ─────────────────────────────────────────────────────────────────────
-- select tablename from pg_publication_tables
-- where pubname = 'supabase_realtime'
--   and tablename in ('watch_parties', 'chat_messages');
-- (harus return 2 rows)
--
-- select policyname, cmd from pg_policies
-- where tablename in ('watch_parties', 'chat_messages')
-- order by tablename, cmd;

-- VibeNime — Fix RLS policy untuk watch_parties (delta migration)
-- Run di Supabase SQL Editor untuk fix error 42501 saat tap "Akhiri Pesta".
--
-- Issue:
--   Policy lama `with check (auth.uid() = host_user_id)` reject UPDATE karena
--   trigger `update_party_updated_at` modify NEW row → RLS re-evaluate gagal.
--   Plus tidak ada SELECT policy untuk host setelah is_active=false.
--
-- Fix:
--   1. Hapus `with check` dari policy update (gunakan `using` saja)
--   2. Tambah SELECT policy untuk host membaca row sendiri
--   3. Spesifik `to authenticated` di semua policy modify

-- ─────────────────────────────────────────────────────────────────────
-- Update policies di watch_parties
-- ─────────────────────────────────────────────────────────────────────

-- 1. SELECT: anonymous bisa baca party aktif (sudah ada — keep)
drop policy if exists "Anyone can read active parties" on watch_parties;
create policy "Anyone can read active parties"
  on watch_parties for select using (is_active = true);

-- 2. SELECT: host bisa baca party-nya sendiri (untuk endParty UPDATE RETURNING)
drop policy if exists "Host can read own party" on watch_parties;
create policy "Host can read own party"
  on watch_parties for select
  to authenticated
  using (auth.uid() = host_user_id);

-- 3. INSERT: authenticated user bisa create party DENGAN constraint
--    host_user_id harus = auth.uid() (anti-spoofing)
drop policy if exists "Authenticated can create parties" on watch_parties;
create policy "Authenticated can create parties"
  on watch_parties for insert
  to authenticated
  with check (auth.uid() = host_user_id);

-- 4. UPDATE: hanya host yang bisa modify party-nya. TIDAK pakai `with check`
--    karena trigger update_party_updated_at modify NEW row sebelum RLS check.
drop policy if exists "Host can update own party" on watch_parties;
create policy "Host can update own party"
  on watch_parties for update
  to authenticated
  using (auth.uid() = host_user_id);

-- 5. DELETE: hanya host
drop policy if exists "Host can delete own party" on watch_parties;
create policy "Host can delete own party"
  on watch_parties for delete
  to authenticated
  using (auth.uid() = host_user_id);

-- ─────────────────────────────────────────────────────────────────────
-- REPLICA IDENTITY FULL untuk DELETE event di stream filter (chat msg
-- delete + party end propagate live ke viewer)
-- ─────────────────────────────────────────────────────────────────────
alter table watch_parties replica identity full;
alter table chat_messages replica identity full;

-- ─────────────────────────────────────────────────────────────────────
-- Relax chat INSERT policy — semua authenticated user bisa post (bukan
-- cuma admin). Setelah Commit 2 (app-native auth), tiap user yang
-- register otomatis dapat Supabase identity → langsung bisa chat.
-- ─────────────────────────────────────────────────────────────────────
drop policy if exists "Authenticated can post chat" on chat_messages;
drop policy if exists "Anyone authenticated can post chat" on chat_messages;
create policy "Anyone authenticated can post chat"
  on chat_messages for insert
  to authenticated
  with check (auth.uid() = user_id);

-- User boleh hapus chat sendiri (untuk delete diskusi sendiri di chat overlay)
drop policy if exists "User can delete own chat" on chat_messages;
create policy "User can delete own chat"
  on chat_messages for delete
  to authenticated
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- Verifikasi
-- ─────────────────────────────────────────────────────────────────────
-- Run setelah apply untuk konfirmasi:
--
-- select policyname, cmd, roles, qual, with_check
-- from pg_policies
-- where tablename = 'watch_parties'
-- order by cmd, policyname;
--
-- Harusnya return 5 row dengan cmd: SELECT (2x), INSERT, UPDATE, DELETE.
