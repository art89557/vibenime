# VibeNime

> Aplikasi streaming anime mobile bersubtitle Indonesia.
> *"Vibe-mu, anime-mu."*

Tugas kuliah pengembangan aplikasi mobile dengan **Flutter**, mengintegrasikan **AniList GraphQL API** (metadata) dan **Supabase** (auth + catalog + real-time Watch Party).

## Status

✅ **Final — feature-complete + APK ready untuk demo.**

---

## Fitur Utama

| # | Fitur | Highlight |
|---|-------|-----------|
| 1 | **Auth Supabase email/password** | Register/login app-native, AniList jadi optional connector |
| 2 | **Multi-source streaming** | 4-layer fallback chain: Supabase catalog → Consumet mirror → AniList trailer → Mux sample |
| 3 | **Watch Party real-time** | Nonton bareng dengan chat + sync playback + presence count |
| 4 | **Diskusi per anime** | Tab Diskusi dengan post text + emoji gift animated |
| 5 | **Download offline** | dio download archive.org → Hive entry → BetterPlayer `file://` playback |
| 6 | **Search + filter** | Genre AniList real + Year/Season/Format dropdown |
| 7 | **My List sync (opsional)** | Profile → Connect AniList → sync watching/completed/planning |
| 8 | **Admin panel** | Stats dashboard + bulk insert pattern/paste-list, role-gated |
| 9 | **Episode picker + history** | Watched checkmark + resume position + hide unreleased |
| 10 | **Offline-first auth** | Cache user info di secure_storage, boot tanpa internet |

---

## Setup (~10 menit)

### 1. AniList OAuth client (untuk My List sync, optional)
Ikuti [docs/SETUP_ANILIST.md](./docs/SETUP_ANILIST.md).

### 2. Supabase project
1. Buat project di https://supabase.com (free tier OK)
2. **Authentication → Providers → Email**: Enable + **OFF "Confirm email"** (skip verifikasi untuk demo)
3. **SQL Editor** — run urutan ini:
   ```
   sql/init.sql                 (tables video_sources)
   sql/admin_rls.sql            (RLS policy write video_sources)
   sql/multi_source_migration.sql (priority field)
   sql/watch_party.sql          (tables + RLS Watch Party + chat)
   sql/anime_discussions.sql    (tables + RLS Diskusi)
   sql/watch_party_rls_fix.sql  (relax chat RLS + REPLICA IDENTITY)
   sql/admin_setup.sql          (assign role 'admin' ke akun kamu)
   ```

### 3. `.env` config
Copy `.env.example` → `.env`, isi:
```
ANILIST_CLIENT_ID=40780                     # dari step 1
SUPABASE_URL=https://xxx.supabase.co        # dari Supabase Settings → API
SUPABASE_ANON_KEY=sb_publishable_xxx
SAMPLE_STREAM_URL=https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
```

### 4. Run
```powershell
flutter pub get
flutter run
```

---

## Auth Model

**Primary**: Supabase email/password (di-set sebagai default semua user)
**Optional**: AniList OAuth (Profile → Connect) untuk sync My List

| Aksi | Butuh Auth? |
|------|-------------|
| Browse / Search / Detail / Player | ❌ Tidak (mode tamu) |
| Download offline | ❌ Tidak |
| Watch Party / Diskusi / Chat | ✅ Supabase user |
| My List (sync watchlist) | ✅ AniList connect |
| Admin Panel | ✅ Supabase + `role = admin` (lihat `sql/admin_setup.sql`) |

---

## Stack Teknis

| Kategori | Pilihan |
|----------|---------|
| Framework | Flutter 3.x |
| State | Riverpod 2.x |
| Routing | go_router 14.x |
| Player | better_player_plus (HLS/MP4) + youtube_player_flutter |
| Auth | Supabase Auth (email/password) + AniList OAuth (optional) |
| Backend | Supabase (Postgres + Realtime CDC + Presence) |
| Metadata | AniList GraphQL (graphql_flutter) |
| Storage | flutter_secure_storage (token cache) + Hive (history, downloads, search history) |
| Download | dio (browser headers untuk archive.org) + path_provider |
| HTTP | dio + dio_cache_interceptor (cacheFirst untuk AniList) |
| Realtime | Supabase Realtime (CDC for chat + Presence for participant count) |

---

## Dokumentasi

- 📄 [PRD.md](./PRD.md) — Product Requirements
- 📘 [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — Layer diagram + tech stack
- 🗺️ [docs/SCREEN_FLOW.md](./docs/SCREEN_FLOW.md) — User journey per flow
- 🧪 [docs/TESTING.md](./docs/TESTING.md) — Unit + widget test guide
- 🎨 [docs/8_GOLDEN_RULES.md](./docs/8_GOLDEN_RULES.md) — Shneiderman implementation
- 🔧 [docs/SETUP_ANILIST.md](./docs/SETUP_ANILIST.md) — OAuth setup
- 🗄️ [docs/SETUP_SUPABASE.md](./docs/SETUP_SUPABASE.md) — Supabase setup
- ▶️ [docs/ADD_YOUTUBE_VIDEOS.md](./docs/ADD_YOUTUBE_VIDEOS.md) — Tambah source YouTube

---

## Build APK Release

```powershell
flutter clean
flutter pub get
flutter test            # 44+ tests pass
flutter analyze         # 0 issues
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (~55 MB).

Install: `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

---

## Catatan Streaming Source

Source streaming dikelola via Supabase `video_sources` table (per-episode, priority-ranked). Tambah via:
- **Admin Panel** (in-app) — Bulk Insert pattern `{ep:03d}` atau Paste List
- **Direct SQL** — `INSERT INTO video_sources (...)`

Source yang sudah diuji:
- **Internet Archive** (.mp4 direct) — Astro Boy, Berserk 1997, JJK S1-S2 — **bisa download offline**
- **YouTube official** (Muse Asia, Ani-One Asia) — full episodes — streaming only
- **Mux sample HLS** — fallback final untuk anime tanpa source

Lihat plan [docs/SETUP_SUPABASE.md](./docs/SETUP_SUPABASE.md) untuk URL pattern Berserk lengkap.
