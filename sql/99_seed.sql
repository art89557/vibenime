-- ============================================================
-- VibeNime 99_seed.sql — Dummy data (DEV ONLY, opsional)
-- ============================================================

-- VibeNime — Sample seed data
-- Jalankan setelah init.sql untuk populate database dengan video classic dari
-- Internet Archive yang public domain / freely distributed.
--
-- ⚠️  Penting: AniList ID di bawah perlu diverifikasi sebelum di-INSERT.
-- Cara verifikasi:
--   1. Buka https://anilist.co
--   2. Cari nama anime (mis. "Astro Boy 1963")
--   3. Lihat URL: https://anilist.co/anime/{ID}/...
--   4. Update ID di bawah jika berbeda
--
-- Internet Archive URL pattern:
--   https://archive.org/download/{collection-slug}/{filename}
--
-- ─────────────────────────────────────────────────────────────────────

-- Astro Boy / Tetsuwan Atom (1963)
-- AniList: https://anilist.co/anime/4082/Tetsuwan-Atom/  (verify ID!)
insert into video_sources (anilist_id, episode_number, video_url, language, quality, source_type, notes)
values
  (4082, 1, 'https://archive.org/download/astro-boy-1963/Astro%20Boy%20%281963%29%20R1/Astro%20Boy%20S1E001.mp4', 'en', '480p', 'archive_org', 'Astro Boy 1963 — Episode 1'),
  (4082, 2, 'https://archive.org/download/astro-boy-1963/Astro%20Boy%20%281963%29%20R1/Astro%20Boy%20S1E002.mp4', 'en', '480p', 'archive_org', 'Astro Boy 1963 — Episode 2'),
  (4082, 3, 'https://archive.org/download/astro-boy-1963/Astro%20Boy%20%281963%29%20R1/Astro%20Boy%20S1E003.mp4', 'en', '480p', 'archive_org', 'Astro Boy 1963 — Episode 3'),
  (4082, 4, 'https://archive.org/download/astro-boy-1963/Astro%20Boy%20%281963%29%20R1/Astro%20Boy%20S1E004.mp4', 'en', '480p', 'archive_org', 'Astro Boy 1963 — Episode 4'),
  (4082, 5, 'https://archive.org/download/astro-boy-1963/Astro%20Boy%20%281963%29%20R1/Astro%20Boy%20S1E005.mp4', 'en', '480p', 'archive_org', 'Astro Boy 1963 — Episode 5');

-- Astro Boy 2003 (Tetsuwan Atom remake)
-- AniList: https://anilist.co/anime/1818/Tetsuwan-Atom-2003/  (verify!)
insert into video_sources (anilist_id, episode_number, video_url, language, quality, source_type, notes)
values
  (1818, 1, 'https://archive.org/download/tetsuwan-atom-2003/Tetsuwan%20Atom%202003%20-%2001%20%5B576p%20-%20Eng%20Hardsub%5D.mp4', 'en', '576p', 'archive_org', 'Astro Boy 2003 — Episode 1'),
  (1818, 2, 'https://archive.org/download/tetsuwan-atom-2003/Tetsuwan%20Atom%202003%20-%2002%20%5B576p%20-%20Eng%20Hardsub%5D.mp4', 'en', '576p', 'archive_org', 'Astro Boy 2003 — Episode 2'),
  (1818, 3, 'https://archive.org/download/tetsuwan-atom-2003/Tetsuwan%20Atom%202003%20-%2003%20%5B576p%20-%20Eng%20Hardsub%5D.mp4', 'en', '576p', 'archive_org', 'Astro Boy 2003 — Episode 3');

-- Speed Racer X (1997)
-- AniList: https://anilist.co/search/anime?search=speed+racer  (verify!)
-- Catatan: Speed Racer asli (1967) AniList ID berbeda; Speed Racer X = remake 1997
insert into video_sources (anilist_id, episode_number, video_url, language, quality, source_type, notes)
values
  (1571, 1, 'https://archive.org/download/speed-racer-x-1-13/Speed%20Racer%20X%2001.mp4', 'en', '480p', 'archive_org', 'Speed Racer X — Episode 1'),
  (1571, 2, 'https://archive.org/download/speed-racer-x-1-13/Speed%20Racer%20X%2002.mp4', 'en', '480p', 'archive_org', 'Speed Racer X — Episode 2');

-- ─────────────────────────────────────────────────────────────────────
-- Cara tambah video baru (template):
--
-- insert into video_sources
--   (anilist_id, episode_number, video_url, language, quality, source_type, notes)
-- values
--   (XXX, 1, 'https://archive.org/...', 'en', '480p', 'archive_org', 'Description');
-- ─────────────────────────────────────────────────────────────────────

-- Verify — query semua data
-- select anilist_id, episode_number, source_type, quality, notes
-- from video_sources
-- order by anilist_id, episode_number;
