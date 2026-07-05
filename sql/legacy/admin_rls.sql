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
