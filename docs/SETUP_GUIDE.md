# VibeNime — Setup Guide: Video Player & Admin Login

Panduan praktis supaya **video anime beneran main** di player + cara **login
sebagai admin**. Ikuti berurutan dari Bagian 0.

> Ringkasan cepat:
> - **Cara 1** (Admin Panel) — input URL video manual, langsung jalan hari ini.
> - **Cara 2** (wajik-anime-api) — deploy backend scraping sub-Indo, katalog otomatis luas.
> - Admin di-set via SQL di Supabase (akun biasa → di-promote).

---

## Bagian 0 — Prasyarat

- [ ] Flutter SDK terinstall → `flutter doctor` semua hijau
- [ ] Akun Supabase + project sudah dibuat ([supabase.com](https://supabase.com))
- [ ] File `.env` di root project terisi:
  ```
  SUPABASE_URL=https://xxxxx.supabase.co
  SUPABASE_ANON_KEY=eyJhbGci...
  ```
- [ ] `flutter pub get` sukses tanpa error

---

## Bagian 1 — Setup Database (jalankan SQL 00–04)

Buka **Supabase Dashboard → SQL Editor → New query**, lalu copy-paste isi
tiap file dan klik **Run**. Jalankan **berurutan**:

| Urutan | File | Membuat |
|--------|------|---------|
| 1 | `sql/00_core.sql` | video_sources, app_config, anime_source_mapping |
| 2 | `sql/01_user.sql` | user_profiles (+role/xp/level), user_badges + RPC |
| 3 | `sql/02_social.sql` | friendships, direct_messages, activity_events, anime_discussions |
| 4 | `sql/03_watchparty.sql` | watch_parties, chat_messages |
| 5 | `sql/04_storage.sql` | bucket avatars + banners |
| 6 | `sql/05_reports.sql` | episode_reports (laporan episode rusak) |

**Verifikasi** — jalankan query ini, harus return **12**:
```sql
select count(*) from information_schema.tables where table_schema = 'public';
```

> File `sql/99_seed.sql` opsional (data dummy untuk dev). Skip untuk produksi.

---

## Bagian 2 — Login sebagai Admin

### Step 2.1 — Register akun normal
Buka app → **Daftar** → isi email + username + password. Akun ini awalnya
role `user` biasa (belum admin).

### Step 2.2 — Ambil UUID akun
Di Supabase SQL Editor:
```sql
select id, email from auth.users where email = 'kamu@email.com';
```
Copy nilai `id` (UUID).

### Step 2.3 — Set role admin (DUA tempat — WAJIB keduanya!)

App membaca role dari **`user_metadata`**, tapi RPC admin (dashboard, ban,
promote) membaca dari **`user_profiles`**. Set keduanya:

```sql
-- 1. Untuk gating UI app (Settings → section ADMIN muncul)
update auth.users
set raw_user_meta_data = raw_user_meta_data || '{"role":"super_admin"}'::jsonb
where email = 'kamu@email.com';

-- 2. Untuk RPC admin (dashboard stats, ban/promote user)
update public.user_profiles set role = 'super_admin'
where user_id = '<UUID-dari-step-2.2>';
```

> Role tersedia: `user` (default), `admin`, `super_admin`.
> - `admin` → bisa ban user + moderasi pesan + kelola catalog
> - `super_admin` → semua di atas + promote/demote admin lain

### Step 2.4 — Logout + login ulang
Penting: **logout lalu login ulang** supaya session refresh dan
`user_metadata.role` ter-load. Setelah itu **Settings → section ADMIN**
muncul dengan 4 menu:
- Dashboard (stats global)
- User Management (ban / promote)
- Moderasi Pesan
- Video Catalog

> ⚠️ **Kalau menu ADMIN tidak muncul:** kamu kemungkinan cuma set
> `user_profiles.role` tanpa `raw_user_meta_data`. App baca dari metadata —
> pastikan query #1 di Step 2.3 dijalankan + login ulang.

---

## Bagian 3 — CARA 1: Video via Admin Panel (manual, cepat)

Cara tercepat agar video main: input URL langsung. Cocok untuk demo + beberapa
anime pilihan.

### Step 3.1 — Buka form tambah source
**Settings → ADMIN → Video Catalog → tombol "+"**

### Step 3.2 — Isi form
| Field | Contoh | Catatan |
|-------|--------|---------|
| **Title** | `Spy x Family — Episode 1` | label internal (bebas) |
| **AniList ID** | `140960` | ID anime di anilist.co — tombol **"Cek"** buka AniList untuk verifikasi |
| **Source Type** | pilih chip | lihat tabel di bawah |
| **Video URL** | sesuai source type | direct link atau YouTube URL |
| **Episode Number** | `1` | nomor episode |

### Step 3.3 — Pilihan Source Type
| Type | Untuk | Contoh URL |
|------|-------|-----------|
| `youtube` | Anime official (Muse Asia, Ani-One) | `youtube.com/watch?v=xxxx` → app extract video ID |
| `archive_org` | Anime public domain (legal) | `archive.org/download/.../episode.mp4` |
| `cloudflare_r2` | Self-host R2 bucket | `pub-xxx.r2.dev/episode.mp4` |
| `mux` | Test stream | `test-streams.mux.dev/x36xhzz/x36xhzz.m3u8` |
| `manual` | Direct link lain (Doodstream/B2/GDrive) | `https://.../video.mp4` atau `.m3u8` |

### Step 3.4 — Cara dapat URL video gratis
- **YouTube (paling legal & gampang):** cari anime official di channel
  [Muse Asia](https://www.youtube.com/@MuseAsia) / [Ani-One Asia](https://www.youtube.com/@Ani-OneAsia)
  → copy URL → source type `youtube`. App otomatis extract video ID.
- **archive.org:** cari anime classic public domain → klik file → copy link
  "download .mp4" → source type `archive_org`.
- **Host gratis (Doodstream/Filemoon/dll):** ambil **direct link** hasil
  extractor (bukan halaman embed) → source type `manual`. ⚠️ gampang broken,
  perlu update berkala.

### Step 3.5 — Save → tonton
Save → buka **Detail anime** (yang AniList ID-nya match) → tombol **Watch** →
player ambil dari `video_sources` (Layer 1) → video main.

**Multi-source per episode:** input beberapa row untuk episode yang sama
dengan `priority` beda (1 = utama, 2 = fallback). Player coba priority 1 dulu;
kalau gagal, switch otomatis.

### Step 3.6 — Test cepat tanpa URL real
Mau cek player jalan dulu? Pakai Mux test stream:
- Source Type: `mux`
- Video URL: `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`
- Save → Watch → Big Buck Bunny main = player OK ✅

> Bahkan tanpa input apapun, player otomatis fallback ke Mux sample
> (`Env.sampleStreamUrl`) sebagai Layer 3 — jadi selalu ada yang main.

---

## Bagian 4 — CARA 2: Deploy API Anime Indonesia (scraping otomatis)

Untuk katalog luas otomatis (**Otakudesu / Samehadaku**, sub Indonesia) tanpa
input manual per episode. Pakai **wajik-anime-api**. Butuh deploy server sendiri.

> ⚠️ **Wajib deploy sendiri.** Public demo `wajik-anime-api.vercel.app` sering
> mati total (scraper 404). App otomatis fallback ke demo itu kalau `.env`
> kosong, tapi jangan diandalkan untuk produksi.

### Step 4.1 — Clone wajik-anime-api
```bash
git clone https://github.com/wajik45/wajik-anime-api.git vibenime-scraper
cd vibenime-scraper
npm install
```

### Step 4.2 — Deploy ke Vercel (gratis)
Cara termudah: push repo ke GitHub-mu → buka [vercel.com](https://vercel.com) →
**Add New → Project → Import** repo → Deploy. Vercel auto-detect serverless Node.
Atau via CLI:
```bash
npm i -g vercel
vercel login
vercel deploy --prod
# Output: https://vibenime-scraper.vercel.app
```

### Step 4.3 — Set endpoint di .env
Tambahkan di `.env`:
```
ANIME_API_URL=https://vibenime-scraper.vercel.app
```
App baca via `Env.animeApiUrl` di `IndoAnimeClient`. Restart app (`flutter run`
ulang) supaya `.env` ter-reload. **Tanpa trailing slash.**

### Step 4.4 — Test backend
```bash
curl "https://vibenime-scraper.vercel.app/otakudesu/search?q=naruto"
# Harus return JSON { ..., "data": { "animeList": [ { "animeId": "...", ... } ] } }
```
Di app: buka anime → **Watch** → muncul source **Otakudesu / Samehadaku** di
dropdown picker player (di samping YouTube / Mux). Pilih salah satu.

### Step 4.5 — Cara kerja & catatan playback
App otomatis: cari judul anime → resolve episodeId → ambil stream. Hasilnya:
- **Direct `.mp4`/`.m3u8`** → diputar `better_player` (ada kontrol kualitas, PiP).
- **Embed iframe** (Doodstream/desustream/dll) → diputar via **WebView**
  (hardsub Indo). ⚠️ embed **hanya jalan di mobile** (Android/iOS); di web/desktop
  pilih source lain. Embed juga **tidak track progress** tonton.

### Step 4.6 — Maintenance & legal
- ⚠️ Scraper rutin rusak saat situs sumber ganti domain/obfuscation → tarik
  update dari upstream wajik-anime-api berkala.
- **Web/desktop:** banyak host block browser (CORS) + embed tak jalan → utamakan
  source legal (YouTube/katalog admin) di platform itu.
- **Legal:** ini link aggregator (tidak host konten). Gunakan dengan bijak +
  cantumkan disclaimer di app-mu.

> ⚠️ **Catatan penting:** situs sumber Indo (otakudesu/samehadaku) sering
> **memblok IP datacenter (403)**. Deploy Vercel/Railway bisa kena. Kalau source
> Indo gagal terus, pakai **CARA 3 (Miruro)** yang lebih andal, atau self-host
> wajik di IP rumah/VPS residensial.

---

## Bagian 4B — CARA 3: Miruro-API (M3U8 langsung, sub EN) — paling andal

Backend Python yang balas **M3U8/HLS langsung** + subtitle + timestamp
intro/outro, di-index pakai **AniList ID** (tak perlu tebak judul). Sub Inggris.
Tidak pakai embed → main mulus di `better_player` (semua platform).

### Step 4B.1 — Clone + jalankan lokal
```bash
git clone https://github.com/walterwhite-69/Miruro-API.git
cd Miruro-API
pip install -r requirements.txt
uvicorn api:app --host 0.0.0.0 --port 8000
# buka http://localhost:8000/ untuk dokumentasi interaktif
```

### Step 4B.2 — Deploy (repo SUDAH ada `Dockerfile` yang benar)
`Dockerfile`-nya sudah `uvicorn api:app --host 0.0.0.0 --port ${PORT:-8000}`
→ host Docker apa pun otomatis jalan (PORT diurus host). **Fork dulu** repo
`walterwhite-69/Miruro-API` ke GitHub-mu, lalu pilih host:

- **Koyeb** (rekomendasi — gratis, target asli repo): New App → pilih repo fork →
  auto-detect **Dockerfile** → Deploy. Dapat URL `https://xxx.koyeb.app`.
- **Railway**: New Project → Deploy from GitHub repo → auto-detect Dockerfile →
  Generate Domain. (Atau tanpa Docker: start `uvicorn api:app --host 0.0.0.0 --port $PORT`.)
- **Render**: New → **Web Service** → Runtime **Docker** → Deploy.

> **Set juga env `API_KEY`** di dashboard host (mis. `API_KEY=rahasia123`) — ini
> mengunci backend supaya tak dipakai sembarang orang (lihat Step 4B.6). Lalu
> isi `MIRURO_API_KEY=rahasia123` di `.env` app.

### Step 4B.3 — Set di .env
```
MIRURO_API_URL=https://<deploy-kamu>
# Opsional (kalau backend di-lock — lihat Step 4B.6):
MIRURO_API_KEY=<api-key-yang-sama-dengan-server>
```
(tanpa trailing slash). Restart app (`flutter run` ulang).

### Step 4B.4 — Test backend
> ⚠️ Backend **menolak request tanpa `Referer`/`Origin`** (balas
> `403 Invalid Origin`). Saat test pakai curl, sertakan header Referer:
```bash
curl -H "Referer: https://www.miruro.tv/" "https://<url>/episodes/178005"
# → JSON { providers: { kiwi, hop, bee, ... } }
curl -H "Referer: https://www.miruro.tv/" \
  "https://<url>/watch/kiwi/178005/sub/animepahe-1"
# → { streams: [ { url: ".../uwu.m3u8", type:"hls", quality:"1080p" }, ... ] }
```
App **otomatis** mengirim header `Referer`/`Origin` (+ `x-api-key` bila di-set),
jadi tak perlu konfigurasi tambahan di sisi app. Di app: buka anime → **Watch** →
source **"Miruro (EN)"** muncul → M3U8 main.

### Step 4B.5 — Catatan playback (terverifikasi vs backend asli)
- Tiap anime punya **banyak provider** (kiwi/hop/bee/bonk/dll). App otomatis
  iterasi & pilih provider pertama yang kasih **HLS** (sebagian provider cuma
  `embed` → otomatis dilewati).
- Stream campur HLS + `embed`; app **buang yang embed** (kwik.cx dll) karena
  tak playable di better_player.
- Sub **EN**: `kiwi` (animepahe) **hard-sub** (no VTT); provider lain kadang
  punya **soft-sub** + **intro/outro** (dipakai tombol Skip). Kalau intro/outro
  kosong → otomatis fallback ke **AniSkip**.
- Tetap **link aggregator** — sertakan disclaimer.

### Step 4B.6 — Keamanan deploy (opsional tapi disarankan)
Tanpa konfigurasi, backend menerima Referer apa pun (siapa saja bisa pakai
endpoint-mu). Untuk mengunci, set env di server:
- `API_KEY=rahasia123` → lalu set `MIRURO_API_KEY=rahasia123` di `.env` app
  (app kirim header `x-api-key`).
- (Web) `ALLOWED_ORIGINS=https://domainmu.com` → batasi by Origin.

### Step 4B.7 — Test cepat via LAN (tanpa deploy)
Mau coba tanpa deploy? Jalankan `uvicorn ... --host 0.0.0.0 --port 8000` di PC,
lalu di `.env`: `MIRURO_API_URL=http://<IP-LAN-PC>:8000` (HP & PC satu WiFi).
> ⚠️ Android blok **cleartext HTTP** by default. Untuk URL `http://` (bukan
> https), tambah `android:usesCleartextTraffic="true"` di `AndroidManifest.xml`
> sementara, atau pakai tunnel (ngrok/cloudflared) yang kasih URL `https://`.

---

## Bagian 4C — Build Release (mesin RAM terbatas)

R8/ProGuard (shrinker) rakus RAM — di mesin ~7GB sering **OOM** ("Gradle daemon
disappeared"). `gradle.properties` sudah dibatasi (`-Xmx2048M`), dan untuk release
pakai kombinasi ini:

```bash
# WAJIB sebelum release (hindari .env stale ke-bundle):
flutter clean

# Release TANPA R8 + APK per-ABI (lebih kecil dari fat-APK walau tanpa shrink):
flutter build apk --release --no-shrink --split-per-abi
# Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (HP modern)
```

Catatan:
- `--no-shrink` mematikan R8 → build lolos di RAM kecil. `--split-per-abi`
  memangkas ukuran (hanya native lib 1 arsitektur) — biasanya lebih kecil dari
  fat-APK ter-shrink sekalipun.
- **Crash reporting (`crash_logs`) hanya aktif di build release** — jadi jalur
  ini juga prasyarat observability produksi.
- Kalau build di mesin ber-RAM besar (CI), boleh release normal (R8 aktif,
  `proguard-rules.pro` sudah ada).

---

## Bagian 5 — Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Menu ADMIN tidak muncul di Settings | Pastikan `raw_user_meta_data.role` ter-set (Step 2.3 query #1) + **logout/login ulang** |
| Video cuma loading, tidak main | Cek URL valid (buka di browser dulu), pastikan Source Type cocok dengan URL |
| "Tidak ada sumber tersedia" | Fallback Mux harusnya selalu ada — cek `SAMPLE_STREAM_URL` di `.env` tidak kosong |
| Source Otakudesu/Samehadaku tidak muncul | `ANIME_API_URL` belum di-set / instance mati — test `curl ".../otakudesu/search?q=naruto"` dulu |
| Source "Miruro (EN)" tidak muncul | `MIRURO_API_URL` belum di-set / backend mati — test `curl ".../episodes/178005"` |
| Miruro muncul tapi M3U8 403/loading | Provider tsedang block — pilih anime/episode lain atau source lain di dropdown |
| Source muncul tapi cuma loading | Kemungkinan embed gagal load — coba source lain di dropdown, atau buka di HP |
| Embed "hanya bisa di mobile" | Normal — embed iframe tak jalan di web/desktop. Pilih source direct/YouTube/Mux |
| Episode kebuka salah | Mapping by-judul meleset (filler/split-cour) — laporkan via tombol di player |
| Player error di web (CORS) | Host block browser — test di **mobile**, utamakan source legal di web |
| Dashboard admin error "Forbidden" | `01_user.sql` belum di-run ATAU `user_profiles.role` belum `super_admin` (Step 2.3 query #2) |
| AniList ID tidak ketemu | Cek ID benar di anilist.co (angka di URL `/anime/<ID>/`) |

---

## Bagian 6 — Referensi: Alur Player

Saat buka episode, `streamPayloadsProvider` kumpulkan source dari 4 layer:

```
Layer 1   : video_sources (admin manual)       ← CARA 1
Layer 1.5 : wajik-anime-api (Otakudesu/Samehadaku, scraping)  ← CARA 2
Layer 2   : YouTube trailer (dari AniList)
Layer 3   : Mux sample stream (SELALU ada)

SEMUA layer di-append jadi daftar source SEJAJAR (hybrid). Player render
source pertama; user bisa pilih bebas via dropdown picker. Auto-switch ke
source berikutnya hanya kalau yang aktif error saat playback.

Render per jenis: YouTube → YoutubePlayer · embed iframe → WebView ·
direct .mp4/.m3u8 → better_player.
```

**File terkait:**
- `lib/features/player/data/streaming_repository.dart` — gabung semua layer
- `lib/features/player/data/indo_anime_client.dart` — client wajik-anime-api
- `lib/features/player/presentation/player_screen.dart` — 3 jenis player + picker
- `lib/features/admin/presentation/admin_form_screen.dart` — form input source
- `lib/core/utils/source_type.dart` — daftar source type
- `sql/00_core.sql` — tabel `video_sources`

---

## Quick Reference — Setup Tercepat (5 menit)

```
1. Run sql/00_core.sql s/d 04_storage.sql di Supabase
2. Register akun di app
3. SQL: set role super_admin (2 query di Step 2.3)
4. Logout + login ulang
5. Settings → ADMIN → Video Catalog → +
6. Title: "Test", AniList ID: 21 (One Piece), Source: mux,
   URL: https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8, Episode: 1
7. Save → buka One Piece → Watch → video main ✅
```
