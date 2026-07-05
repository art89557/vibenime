# Panduan Setup Supabase untuk VibeNime

> Estimasi waktu: **20-30 menit**
> Biaya: **Gratis** (Supabase free tier)
> Output: Database video catalog yang dapat diakses dari aplikasi Flutter

---

## Apa yang Dibuat?

Database `video_sources` di Supabase yang berisi mapping `anime_id → video URL`. Saat user buka episode, app cek Supabase dulu — kalau ada video link, pakai itu. Kalau tidak ada, fallback ke YouTube trailer / Mux sample.

**Hasilnya**: anime classic seperti Astro Boy bisa play video real (dari Internet Archive) lewat database Supabase, bukan Big Buck Bunny generic.

---

## Langkah 1 — Signup Supabase (5 menit)

1. Buka https://supabase.com
2. Klik **Start your project** atau **Sign Up**
3. Login dengan GitHub (paling cepat) atau email
4. Verifikasi email (kalau pakai email)

---

## Langkah 2 — Create Project (3 menit)

1. Setelah login, klik **New Project**
2. Pilih organization (default ada satu)
3. Isi:
   - **Project name**: `vibenime`
   - **Database password**: generate password yang kuat (simpan baik-baik, butuh untuk SQL admin)
   - **Region**: pilih **Southeast Asia (Singapore)** untuk latency Indonesia terbaik
   - **Plan**: Free
4. Klik **Create new project**
5. Tunggu provisioning ~1-2 menit (database PostgreSQL di-spin up)

---

## Langkah 3 — Catat Credentials (1 menit)

Setelah project ready:

1. Di sidebar kiri, klik ikon **Settings** (gear) → **API**
2. Catat 2 nilai berikut (akan dipakai di `.env`):
   - **Project URL** — contoh: `https://abcdefg.supabase.co`
   - **anon public key** — diawali `eyJhbGciOi...` (panjang)

> ⚠️ Jangan share `service_role key` ke siapa pun — itu untuk server-side admin. Cukup `anon public key` untuk client app.

---

## Langkah 4 — Create Schema via SQL Editor (5 menit)

1. Di sidebar, klik **SQL Editor**
2. Klik **+ New query**
3. Copy-paste isi file [`sql/init.sql`](../sql/init.sql) di proyek ini
4. Klik **Run** (atau Ctrl+Enter)
5. Verifikasi: di sidebar **Table Editor** → muncul tabel `video_sources`

---

## Langkah 5 — Insert Seed Data (5 menit)

1. **SQL Editor** → **+ New query**
2. Copy-paste isi file [`sql/seed.sql`](../sql/seed.sql)
3. **Run**
4. Verifikasi: **Table Editor** → `video_sources` → ada beberapa rows

---

## Langkah 6 — Update `.env` di Flutter Project (2 menit)

Edit `D:\VibeNime\.env`:

```env
# Existing
ANILIST_CLIENT_ID=40780
SAMPLE_STREAM_URL=https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8

# Tambahkan baris berikut:
SUPABASE_URL=https://abcdefg.supabase.co        # GANTI dengan URL Anda
SUPABASE_ANON_KEY=eyJhbGciOi...                  # GANTI dengan anon key Anda
```

---

## Langkah 7 — Verifikasi di App

1. Build & install APK:
   ```bash
   flutter build apk --debug
   flutter install -d <DEVICE_ID> --debug
   ```
2. Buka app → cari anime classic yang ada di seed (mis. **Astro Boy** atau **Speed Racer**)
3. Tap episode → Player buka dengan **video real dari Internet Archive** (bukan Mux Big Buck Bunny)

Kalau anime tidak ada di Supabase, app fallback ke YouTube trailer / Mux sample (existing logic).

---

## Cara Tambah Video Baru

Untuk menambah anime ke catalog:

1. Cari **AniList ID** anime (lewat AniList.co URL: `https://anilist.co/anime/12345/...` → ID = 12345)
2. Cari video URL — **Internet Archive** paling reliable. Search di https://archive.org untuk anime
3. Di Supabase **SQL Editor**, jalankan:

```sql
INSERT INTO video_sources (anilist_id, episode_number, video_url, language, quality, source_type)
VALUES (12345, 1, 'https://archive.org/download/.../episode01.mp4', 'en', '480p', 'archive_org');
```

Refresh app → episode akan play dari URL baru.

---

## Troubleshooting

### "Supabase connection failed" di app
- Cek `.env` URL & anon key — pastikan tidak ada spasi/typo
- Cek Supabase dashboard → project status "Active"
- Cek koneksi internet HP

### Video tidak play
- Cek URL `.mp4` bisa dibuka di browser secara langsung
- Internet Archive kadang lambat, butuh buffering
- Cek HP support format (.mp4 H.264 paling kompatibel)

### "Permission denied" saat query
- Cek RLS policy di Supabase dashboard → Auth → Policies → table `video_sources`
- Harus ada policy "Anyone can read" untuk public read

---

## Resource

- [Supabase Docs](https://supabase.com/docs)
- [supabase_flutter package](https://pub.dev/packages/supabase_flutter)
- [Internet Archive anime collections](https://archive.org/details/anime)
