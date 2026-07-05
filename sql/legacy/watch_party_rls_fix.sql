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
