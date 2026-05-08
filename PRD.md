# VibeNime — Product Requirements Document

> Aplikasi streaming anime mobile bersubtitle Indonesia
> Dibuat dengan Flutter + AniList API + Sample HLS Stream
> **Versi:** 1.2 | **Tanggal:** 2026-05-08

---

## Context

**VibeNime** adalah aplikasi streaming anime mobile (Flutter) bersubtitle Indonesia, dibuat sebagai tugas kuliah. Aplikasi ini meniru pengalaman aplikasi *Wibuku* yang populer di Indonesia, dengan pendekatan:

- **AniList API** (GraphQL) → sumber metadata anime real: judul, sinopsis, cover, episode count, rating, genre, list user.
- **Sample HLS Stream** → video playback untuk MVP/demo, dengan abstraksi `StreamingRepository` yang siap di-swap ke provider berlisensi di production.

> 📌 **Lihat §6.2 "Technical Decision: Streaming Source"** untuk konteks lengkap kenapa pendekatan ini dipilih.

Tujuan dokumen ini: menetapkan PRD (Planning) sebagai langkah pertama mengikuti workflow tugas (Planning → Frontend → Backend → Integration → Deploy → Testing), agar pengembangan terarah dan demo lancar.

**Keputusan akhir yang sudah disepakati:**
- Scope: **Lengkap dengan Auth** — login AniList OAuth, sinkronisasi watchlist & history.
- Streaming: **Sample HLS** untuk MVP (Mux test stream, multi-bitrate, public, legal).
- Subtitle: track sample EN dari Mux + slot Indonesian siap di-wire kalau perlu.
- State Management: **Riverpod**.
- Tidak butuh deployment backend — hanya register OAuth client di AniList.

---

## 1. Konsep Produk

### 1.1 Visi
> "Tonton anime favorit dengan subtitle Indonesia, semudah membuka YouTube, sepersonal AniList."

### 1.2 Value Proposition
| Pengguna mendapat | Karena VibeNime menyediakan |
| --- | --- |
| Katalog anime lengkap & up-to-date | AniList sebagai sumber metadata terpercaya |
| Streaming langsung dari aplikasi | Consumet meng-scrape provider streaming |
| Subtitle (ID/EN) saat menonton | Track subtitle dari Consumet di-load ke player |
| List "Watching / Plan to Watch" tersinkron | OAuth AniList → mutate list user |
| UI rapi & mobile-first | Flutter Material 3 + dark mode |

### 1.3 Target Pengguna
- **Wibu mahasiswa Indonesia** umur 17–25 tahun, terbiasa pakai aplikasi tracking anime tapi ingin nonton di satu tempat.
- **Penilai tugas (dosen)** — butuh aplikasi yang berjalan stabil saat demo, alur jelas, kode rapi.

---

## 2. Daftar Fitur

### 2.1 MVP (wajib selesai)
1. **Splash & Onboarding** — branding + minta izin login AniList (opsional skip → guest).
2. **Auth AniList (OAuth Implicit Grant)** — token disimpan di `flutter_secure_storage`.
3. **Home / Discover** — section: Trending, Popular Season, Top Rated, Upcoming.
4. **Search** — query AniList by title, filter genre & format.
5. **Anime Detail** — banner, sinopsis, info (status, episode count, studio, score), list episode.
6. **Episode Player** — `better_player`, subtitle track switcher, quality switcher, seek/pause.
7. **My List (Sync)** — tampilkan list user dari AniList: Watching, Planning, Completed, Dropped.
8. **History (lokal)** — episode terakhir ditonton + posisi resume (Hive).
9. **Settings** — toggle dark mode, base URL Consumet (read-only di MVP), logout.

### 2.2 Nice-to-Have (kalau waktu cukup)
- Push notification episode baru (FCM).
- Download offline episode.
- Komentar/rating per anime (mutation AniList).
- Filter advanced di search (year, season, popularity).

### 2.3 Out of Scope
- Akun custom (auth via AniList saja).
- Pembayaran/premium tier.
- Live streaming.

---

## 3. User Flow (Alur Logika)

```
[Splash]
   │
   ▼
[Cek token AniList di secure storage]
   │
   ├── Ada token & valid ──► [Home]
   │
   └── Tidak ada / expired ──► [Login Screen]
                                  │
                                  ├── Login AniList (WebView OAuth) ──► simpan token ──► [Home]
                                  │
                                  └── Skip (Guest mode) ──► [Home tanpa My List]

[Home (Discover)]
   │  Bottom Nav: Home | Search | My List | Settings
   │
   ├── Tap card anime ──► [Anime Detail]
   │                        │
   │                        ├── Tap episode ──► [Player]
   │                        │                     ├── Pilih subtitle track
   │                        │                     ├── Pilih quality
   │                        │                     └── Posisi disimpan ke History
   │                        │
   │                        └── Tap "Add to List" ──► mutation AniList (butuh login)
   │
   ├── [Search] ──► query AniList ──► hasil grid ──► [Anime Detail]
   ├── [My List] ──► fetch AniList user list ──► tab Watching/Planning/Completed
   └── [Settings] ──► theme, logout, info
```

### Mapping Layar ↔ API
| Layar | API call utama | Caching |
| --- | --- | --- |
| Home | AniList `Page(trending,popular,top)` GraphQL | 30 menit |
| Detail | AniList `Media(id) { episodes, ... }` | 1 jam |
| Episode list | Sintesa lokal dari `episodeCount` AniList | — |
| Player | Sample HLS (Mux test stream) | — |
| My List | AniList `MediaListCollection(userId)` | 5 menit |

---

## 4. Arsitektur Teknis

### 4.1 Pendekatan
**Clean-ish Architecture + Feature-First Folder + Riverpod**.
Tiap fitur punya layer: `data` (datasource + repo impl) → `domain` (entity + repo abstract) → `presentation` (screen + provider/notifier + widget).

Untuk tugas kuliah, kita pakai versi **lite**: skip usecase formal kalau tidak menambah kejelasan, langsung repo → notifier.

### 4.2 Diagram Komponen
```
┌──────────────────────────────────────────┐
│              Presentation                 │
│   Screens ─ Widgets ─ Riverpod Providers  │
└──────────────┬───────────────────────────┘
               │
┌──────────────▼───────────────────────────┐
│              Domain                       │
│   Entities ─ Repository (abstract)        │
└──────────────┬───────────────────────────┘
               │
┌──────────────▼───────────────────────────┐
│              Data                         │
│   Repository Impl                         │
│   ├─ Remote: AniListClient (graphql_flutter)
│   ├─ Sample: SampleStreamingRepository    │
│   └─ Local : Hive boxes + SecureStorage   │
└───────────────────────────────────────────┘
```

### 4.3 Struktur Folder
```
lib/
├── main.dart
├── app.dart                      # MaterialApp + theme + router
├── core/
│   ├── config/                   # env, base URLs
│   ├── theme/                    # ThemeData light/dark
│   ├── router/                   # go_router config
│   ├── network/                  # dio interceptors, error mapper
│   └── storage/                  # secureStorage, hive init
├── features/
│   ├── auth/
│   │   ├── data/                 # anilist_oauth_datasource.dart
│   │   ├── domain/               # auth_repository.dart, user.dart
│   │   └── presentation/         # login_screen, auth_provider
│   ├── discover/                 # Home
│   ├── search/
│   ├── anime_detail/
│   ├── player/
│   ├── my_list/
│   ├── history/
│   └── settings/
└── shared/
    ├── widgets/                  # AnimeCard, EpisodeTile, LoadingShimmer
    └── models/                   # base DTOs reusable
```

### 4.4 State Management Pattern (Riverpod)
- `authProvider` (StateNotifier) — status login + user.
- `discoverProvider` (FutureProvider.family) — section param.
- `animeDetailProvider` (FutureProvider.family) — by ID.
- `playerProvider` (StateNotifier) — current episode, subtitle, quality, position.
- `myListProvider` (AsyncNotifier) — refresh-able list.
- `historyProvider` (Notifier) — Hive-backed.

---

## 5. Stack & Dependencies

| Kategori | Pilihan | Alasan |
| --- | --- | --- |
| Framework | Flutter 3.x (stable) | Cross-platform, syllabus tugas |
| Bahasa | Dart | — |
| State | `flutter_riverpod` ^2 | Sudah disepakati |
| Routing | `go_router` | Deklaratif, support deep-link |
| HTTP | `dio` + `dio_cache_interceptor` | Interceptor auth, cache otomatis |
| GraphQL | `graphql_flutter` | Untuk AniList |
| Player | `better_player` | Support HLS + subtitle multi-track |
| OAuth | `flutter_web_auth_2` | OAuth implicit AniList |
| Secure Storage | `flutter_secure_storage` | Simpan access_token |
| Local DB | `hive` + `hive_flutter` | History & cache ringan |
| Env | `flutter_dotenv` | Simpan base URL Consumet |
| Image | `cached_network_image` | Cover anime |
| Lint | `flutter_lints` + `very_good_analysis` | Kualitas kode |
| Test | `flutter_test`, `mocktail` | Unit + widget test |

---

## 6. Strategi API

### 6.1 AniList (GraphQL)
- **Endpoint:** `https://graphql.anilist.co`
- **Auth:** Bearer token (OAuth Implicit Grant)
- **Setup:** daftar app di AniList Developer Settings → dapat `client_id`
- **Redirect URL:** `vibenime://auth-callback`
- **Query yang disiapkan:** `Trending`, `Popular`, `MediaSearch`, `MediaDetail`, `MediaListCollection`, `SaveMediaListEntry`, `Viewer`

### 6.2 Technical Decision: Streaming Source

**Konteks:** Awalnya rencana memakai scraper publik (Consumet, lalu aniwatch-api). Selama Mei 2026, **kedua repo upstream tersebut kena DMCA takedown** (Q2 2026 = era enforcement agresif terhadap anime piracy):

| Tanggal | Event |
| --- | --- |
| 2026-05-07 | `consumet/api.consumet.org` di-DMCA |
| 2026-05-08 | `ghoshRitesh12/aniwatch-api` di-DMCA |

**Risiko bila lanjut chasing scraper:** scraper berikutnya bisa hilang **saat presentasi tugas berlangsung** — skenario terburuk untuk demo akademik.

**Keputusan:** Untuk MVP/demo tugas, gunakan **Sample HLS Stream** (legal, public, multi-bitrate) sebagai sumber video. Arsitektur `StreamingRepository` (abstract) memungkinkan implementation real provider di-swap di production tanpa mengubah konsumer.

```dart
abstract class StreamingRepository {
  List<Episode> buildEpisodes({required int anilistId, required int? episodeCount});
  Future<StreamPayload> fetchStream({required String episodeId});
}

// MVP:    SampleStreamingRepository  → Mux HLS test stream
// Future: LicensedProviderRepository → Crunchyroll / Bilibili / iQiyi
```

**Sample stream yang dipakai:** `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`
- Multi-bitrate master playlist (mendukung quality switcher demo)
- Public domain (Big Buck Bunny / Mux test asset)
- Tidak akan kena DMCA

**Yang TETAP didemoin secara real ke dosen:**
- Login OAuth ke akun AniList — real
- Discover, Search, Detail — data real dari AniList
- Episode list — disintesa dari `episodeCount` real AniList
- Player play/pause/seek/quality switch/subtitle switch — semua jalan dengan sample
- My List sync — real mutation ke akun AniList
- History resume — real (Hive lokal)

**Penjelasan untuk laporan tugas:**
> *Scraper anime publik tidak reliable di 2026 karena enforcement DMCA agresif. VibeNime memilih arsitektur abstraksi `StreamingRepository` dengan implementasi sample untuk MVP, sehingga demo selalu jalan dan provider berlisensi bisa di-integrasikan di production tanpa rewrite.*

### 6.3 Subtitle Indonesia
- Player menampilkan subtitle switcher dengan opsi Indonesian + English + None.
- Di MVP: track sample English dari Mux. Track Indonesian bisa di-wire dengan file `.vtt` lokal/upload sendiri.
- Di production: track diisi dari provider berlisensi.

---

## 7. UI / Branding

| Aspek | Detail |
| --- | --- |
| Nama | VibeNime |
| Tagline | "Vibe-mu, anime-mu." |
| Primary color | `#7C5CFF` (ungu) |
| Secondary color | `#FF5C8A` (pink) |
| Surface dark | `#0F0F1A` |
| Display font | Poppins |
| Body font | Inter |
| Tone | Modern, playful, ramah wibu, dark-mode-first |

---

## 8. Roadmap (Mengikuti Flow di Gambar Tugas)

| Fase | Output Konkret VibeNime | Estimasi |
| --- | --- | --- |
| **Planning** | PRD ini (selesai) | 1 hari |
| **Frontend Dev** | UI design + screen statis (Home, Detail, Player skeleton) | 5–7 hari |
| **Backend Dev** | Setup AniList client_id + GraphQL queries + sample stream config | 1 hari |
| **Integration** | Hubungkan auth flow, fetch real, player jalan | 4–5 hari |
| **Deploy** | Build APK release signed | 1 hari |
| **Testing** | Unit test repo + widget test + manual test plan | 2 hari |

**Total estimasi:** ±3 minggu kerja santai.

---

## 9. Risiko & Mitigasi

| Risiko | Mitigasi |
| --- | --- |
| Sample stream URL berubah/dihapus | Configurable via `.env` (`SAMPLE_STREAM_URL`); fallback hard-coded di `Env.sampleStreamUrl` |
| Dosen tanya kenapa pakai sample | Jawaban tertulis di PRD §6.2 + README; demonstrasikan abstraksi `StreamingRepository` |
| AniList rate limit (90/min) | Cache via `dio_cache_interceptor`, debounce search |
| Streaming m3u8 tidak jalan di emulator | Test di device fisik, pakai `better_player` |
| OAuth callback ribet di Android | Setup `intent-filter` di `AndroidManifest.xml` |
| Subtitle Indonesia tidak tersedia | Fallback English, dokumentasikan di laporan |

---

## 10. Definition of Done

Aplikasi dianggap **selesai** untuk tugas bila:

- [ ] `flutter run` sukses di Android (target API 34, min 21)
- [ ] Login AniList berhasil → username muncul di header My List
- [ ] Home menampilkan ≥3 section dengan data real dari AniList
- [ ] Search "Naruto" memunculkan hasil >1
- [ ] Detail menampilkan sinopsis + ≥1 episode
- [ ] Player bisa play/pause/seek + ganti subtitle track
- [ ] Tambah anime ke "Plan to Watch" → muncul di tab terkait
- [ ] Tutup app saat menonton → buka lagi → "Lanjut dari menit X"
- [ ] Logout → token terhapus → kembali ke Login Screen
- [ ] Minimal 5 unit test (repo) + 2 widget test berhasil hijau
- [ ] README dengan cara setup, screenshot, dan link Consumet

---

## 11. Langkah Selanjutnya

Setelah PRD ini disetujui, masuk ke **Fase Frontend Development**:

1. `flutter create vibenime` + setup struktur folder
2. Setup `pubspec.yaml` dengan semua dependencies
3. Bikin theme + router + navigation skeleton
4. Buat screen statis dengan data dummy (Home, Detail, Player)

Paralel di sesi terpisah: **Fase Backend Dev** — deploy Consumet self-host + register AniList OAuth client.

---

**Dokumen ini adalah living document.** Update bila ada perubahan scope atau keputusan teknis selama development.
