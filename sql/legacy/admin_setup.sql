-- VibeNime — Admin Role Setup
-- Run di Supabase SQL Editor untuk assign role admin ke user tertentu.
--
-- **Konsep**: Setelah refactor Commit 2, semua user register lewat app
-- dapat Supabase identity normal. Untuk akses Admin Panel, user perlu
-- `user_metadata.role = 'admin'`. Field ini di-cek di client via `AppUser.isAdmin`.
--
-- ⚠️ **Note keamanan**: Ini client-side check. Untuk production, juga add
-- RLS policy di tabel `video_sources` yang require auth.uid() in admin list.
-- Untuk MVP demo, ini sudah cukup.

-- ─────────────────────────────────────────────────────────────────────
-- Cara 1: Set role admin via SQL (paling cepat)
-- ─────────────────────────────────────────────────────────────────────
-- Ganti 'admin@example.com' dengan email user yang mau di-jadikan admin.

UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data || '{"role": "admin"}'::jsonb
WHERE email = 'admin@example.com';

-- Verifikasi: user_metadata.role harus 'admin'
SELECT id, email, raw_user_meta_data->>'role' AS role
FROM auth.users
WHERE email = 'admin@example.com';

-- ─────────────────────────────────────────────────────────────────────
-- Cara 2: Set role admin via Supabase Dashboard (GUI)
-- ─────────────────────────────────────────────────────────────────────
-- 1. Buka Authentication → Users
-- 2. Cari user yang mau dijadikan admin → klik untuk buka detail
-- 3. Tab "User Metadata" → klik Edit
-- 4. Tambah field: { "role": "admin" }
-- 5. Save
--
-- User HARUS logout dan login ulang supaya app baca metadata baru.

-- ─────────────────────────────────────────────────────────────────────
-- Cara 3: Revoke admin role
-- ─────────────────────────────────────────────────────────────────────
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data - 'role'
WHERE email = 'admin@example.com';

-- ─────────────────────────────────────────────────────────────────────
-- List semua admin users
-- ─────────────────────────────────────────────────────────────────────
SELECT id, email, raw_user_meta_data->>'username' AS username, created_at
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'admin'
ORDER BY created_at;
