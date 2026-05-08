# VibeNime

> Aplikasi streaming anime mobile bersubtitle Indonesia.
> *"Vibe-mu, anime-mu."*

Tugas kuliah pengembangan aplikasi mobile dengan **Flutter**, mengintegrasikan **AniList API** (metadata real) dan **sample HLS stream** (video player demo).

## Status

🚧 **Fase Backend Dev — kode siap.** Tinggal register AniList OAuth client lalu jalan.

## Setup (Cepat)

1. **Register OAuth client di AniList** — ikuti [docs/SETUP_ANILIST.md](./docs/SETUP_ANILIST.md) (5 menit)
2. **Copy `.env.example` → `.env`** dan isi `ANILIST_CLIENT_ID`
3. **Jalankan:**
   ```bash
   flutter pub get
   flutter run
   ```

> Tidak perlu deploy backend. Sample HLS stream sudah hard-coded ke Mux test asset (legal & public).

## Catatan Penting tentang Streaming Source

Awalnya rencana memakai scraper publik (Consumet, lalu aniwatch-api). Selama Mei 2026, **kedua repo upstream tersebut kena DMCA takedown** dalam waktu 24 jam. Karena tidak reliable untuk demo akademik, VibeNime **pivot ke sample HLS stream** dengan abstraksi `StreamingRepository` yang siap di-swap ke provider berlisensi (Crunchyroll, Bilibili, iQiyi) di production.

Detail keputusan ini ada di [PRD.md §6.2](./PRD.md#62-technical-decision-streaming-source).

## Dokumen

- 📄 [PRD.md](./PRD.md) — Product Requirements Document lengkap (v1.2)
- 📘 [docs/SETUP_ANILIST.md](./docs/SETUP_ANILIST.md) — Register OAuth AniList

## Stack

| Kategori | Pilihan |
| --- | --- |
| Framework | Flutter 3.x |
| State | Riverpod |
| Routing | go_router |
| Player | better_player_plus (HLS + subtitle multi-track) |
| Auth | OAuth Implicit Grant (AniList) via `flutter_web_auth_2` |
| Storage | `flutter_secure_storage` (token) + Hive (history) |
| HTTP | dio + dio_cache_interceptor |
| GraphQL | graphql_flutter |

## Apa yang Real & Apa yang Sample

| Fitur | Status |
| --- | --- |
| Login OAuth AniList | ✅ **Real** |
| Trending / Popular / Top Rated / Upcoming | ✅ **Real** (AniList) |
| Search anime | ✅ **Real** (AniList) |
| Anime Detail (sinopsis, cover, info, score) | ✅ **Real** (AniList) |
| Episode count | ✅ **Real** (dari AniList) |
| Episode list (id + nomor) | 🟡 Disintesa dari count |
| Video playback | 🟡 Sample HLS (Mux) |
| Subtitle track switcher | 🟡 Track sample EN, slot ID kosong |
| Quality switcher | ✅ Multi-bitrate dari sample HLS |
| Add ke "Plan to Watch" | ✅ **Real** (mutation AniList) |
| My List Sync (Watching/Planning/Completed) | ✅ **Real** (AniList) |
| History resume | ✅ **Real** (Hive lokal) |

## Roadmap

| Fase | Status |
| --- | --- |
| Planning (PRD) | ✅ Selesai |
| Frontend Dev (proyek + theme + router + skeleton) | ✅ Selesai |
| Backend Dev (AniList queries + sample streaming repo) | ✅ Selesai |
| Integration (wire UI ke real data) | ⏳ Berikutnya |
| Deploy (APK release) | ⏳ |
| Testing (unit + widget test) | ⏳ |

Detail tiap fase ada di [PRD.md](./PRD.md).
