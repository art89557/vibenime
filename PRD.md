# VibeNime — Product Requirements Document

> Aplikasi streaming anime mobile (Flutter) — katalog AniList, streaming Miruro self-hosted, fitur sosial real-time
> **Versi:** 2.0 | **Tanggal:** 2026-06-12 | **Status build:** Release APK v1.0.0+1 ✅

---

## Riwayat Versi

| Versi | Tanggal | Perubahan besar |
| --- | --- | --- |
| 1.0–1.2 | 2026-05-08 | PRD awal: AniList OAuth + Sample HLS (Mux), scope MVP tugas kuliah |
| **2.0** | **2026-06-12** | **Pivot besar:** Auth → Supabase (email/password). Streaming → **Miruro-API self-hosted** (M3U8 nyata by AniList ID) + fallback chain. Tambah: sosial (friends/DM/feed/watch party), gamifikasi, admin panel, i18n EN/ID, Jadwal Tayang, Peringkat Anime, Riwayat Menonton, Completed doomscroll, design tokens (radius/animasi ringan). Semua terverifikasi di device nyata. |

---

## Context

**VibeNime** adalah aplikasi streaming anime mobile (Flutter) yang dimulai sebagai tugas kuliah dan berkembang menjadi aplikasi siap rilis. Pendekatan:

- **AniList API** (GraphQL, public — tanpa OAuth) → sumber metadata: judul, sinopsis, cover, episode count, rating, genre, jadwal tayang, popularity.
- **Miruro-API** (self-hosted, Python/FastAPI di Hugging Face Spaces) → sumber streaming **M3U8 langsung** yang di-key oleh **AniList ID** — anime yang diputar otomatis sesuai katalog, tanpa tebak judul. Plus subtitle + timestamp intro/outro.
- **Supabase** → auth (email/password), profil user, fitur sosial real-time, laporan episode, admin.
- **Hive** (lokal) → history tontonan, favorit/library, settings.

> 📌 Lihat **§6.2 "Technical Decision: Streaming Source"** untuk kronologi lengkap perjalanan streaming (Consumet DMCA → scraper Indo diblok → Miruro).

**Keputusan kunci yang berlaku saat ini:**
- Auth: **Supabase email/password** (register/login/guest). OAuth AniList **dihapus** — AniList dipakai sebagai public API saja.
- "My List" → **Library lokal** (Watching/Completed/Planning via Hive), bukan sinkron AniList.
- Streaming: **multi-source fallback chain** (lihat §6.2) dengan Miruro sebagai sumber utama.
- State management: **Riverpod**. Routing: **go_router**. Player: **better_player_plus**.

---

## 1. Konsep Produk

### 1.1 Visi
> "Tonton anime favorit semudah membuka YouTube, sepersonal AniList, serame nonton bareng teman."

### 1.2 Value Proposition
| Pengguna mendapat | Karena VibeNime menyediakan |
| --- | --- |
| Katalog anime lengkap & up-to-date | AniList GraphQL (trending, popular, top, upcoming, completed, jadwal) |
| Streaming nyata langsung dari aplikasi | Miruro-API self-hosted → M3U8 multi-kualitas + subtitle + skip intro/outro |
| Lanjut nonton dari posisi terakhir | History lokal (Hive) + row "Terakhir Ditonton" + timeline Riwayat |
| Nonton bareng teman | Watch Party tersinkron host/viewer + live chat (Supabase Realtime) |
| Komunitas | Friends, DM real-time, activity feed, diskusi per anime, XP/badges |
| UI clean & ringan | Dark-mode-first, design tokens (radius/spacing), animasi ringan + toggle reduce-motion, i18n EN/ID |

### 1.3 Target Pengguna
- **Wibu mahasiswa Indonesia** 17–25 tahun — nonton + tracking + sosial di satu tempat.
- **Penilai tugas (dosen)** — aplikasi stabil saat demo, alur jelas, kode rapi + teruji.

---

## 2. Daftar Fitur

### 2.1 Inti (SELESAI ✅)
1. **Splash & Onboarding** — 3 slide intro (i18n EN/ID), guest mode tersedia.
2. **Auth Supabase** — register/login email-password, logout, guest mode; role admin.
3. **Home / Discover** — header personal, resume card besar, row **Terakhir Ditonton** (+ menu item: Lanjutkan/Detail/Tandai selesai/Hapus), section Trending (entrance stagger ringan)/For You/Top/Upcoming, dan feed **Completed Anime infinite-scroll (doomscroll)**.
4. **Search** — query AniList + filter genre (Mood/Genre picker)/tahun/musim/format, view mode grid-list, sort.
5. **Anime Detail** — hero banner, metric cards, genre pill → filter search, 4 tab (Episode/Sinopsis/Karakter/Diskusi), related anime, status picker (Watching/Completed/Planning), Start Watch Party.
6. **Episode Player** — `better_player_plus` (HLS) + **overlay kontrol kustom** (play/pause, ±10s, seekbar + buffer, speed, quality, fullscreen), **Skip Intro/Outro** (timestamp Miruro, fallback AniSkip), auto-next, share, **lapor episode rusak**, **anti retry-loop** (failover antar source → error state jelas), subtitle switcher.
7. **Jadwal Tayang** — day picker SEN–MIN bertanggal, kartu rilis per jam WIB (views/popularity + rating + status *Sudah Tayang / Menunggu Update Baru / live*), tombol ◀ hari sebelum / hari berikutnya ▶.
8. **Peringkat Anime** — tab **All Time** (popularity) & **Weekly** (trending), badge #1/#2/#3, infinite scroll; entry "Lihat semua" dari Home.
9. **Riwayat Menonton** — timeline per-tanggal, progress bar posisi/durasi per episode, mode **SINGLE/MULTI select-delete**.
10. **Library (lokal)** — tab All/Watching/Completed/Planning (Hive), empty state ramah.
11. **Sosial** — cari teman, friend request/accept/block, profil teman, **DM real-time**, **activity feed**, **Watch Party** (playback tersinkron host→viewer + chat overlay).
12. **Gamifikasi** — XP + badges (Supabase).
13. **Downloads** — unduh episode untuk offline (Internet Archive sources).
14. **Profile & Settings** — edit profil (bio/banner/avatar border/privasi/ganti password), tema light-dark-sistem, **bahasa EN/ID penuh (i18n ARB)**, toggle **Kurangi animasi**, auto-next, auto-skip, notifikasi, kebijakan privasi + ToS in-app, About.
15. **Admin Panel** — dashboard, manajemen user, moderasi, bulk insert video catalog.
16. **Offline UX** — banner "Tidak ada koneksi internet" (connectivity_plus), error state + retry konsisten.

### 2.2 Nice-to-Have (belum)
- Push notification episode baru (FCM).
- Komentar bersarang / reaksi di diskusi.
- Sinkron list ke AniList (butuh OAuth — sengaja dihapus dari scope).

### 2.3 Out of Scope
- Pembayaran/premium tier · Live streaming · Akun OAuth pihak ketiga.

---

## 3. User Flow (Alur Logika)

```
[Splash] ──► [Cek onboardingSeen + sesi Supabase]
   ├── Belum onboarding ──► [Onboarding 3 slide] ──► [Login]
   ├── Ada sesi valid ─────► [Home]
   └── Tidak ada sesi ─────► [Login]
                               ├── Login / Register (Supabase) ──► [Home]
                               └── Guest mode ──► [Home tanpa fitur sosial]

[Bottom Nav]  Beranda | Cari | Pustaka | Jadwal | Saya

[Home] ─ tap card ──► [Anime Detail] ─ tap episode ──► [Player]
   │                      │                              ├── Source chain: Miruro → Indo → Trailer → Sample
   │                      │                              ├── Skip Intro/Outro · auto-next · share · lapor
   │                      │                              └── Posisi tersimpan ke History (Hive)
   │                      ├── Status picker ──► Library lokal
   │                      └── Start Watch Party ──► [Watch Party] (sync + chat)
   ├── Terakhir Ditonton ── long-press ──► menu (Lanjutkan/Detail/Selesai/Hapus)
   │                     └─ "Lihat Lainnya" ──► [Riwayat Menonton]
   ├── Trending "Lihat semua" ──► [Peringkat Anime]
   └── scroll bawah ──► [Completed Anime doomscroll] (auto load-more)

[Saya] ──► Profil · Teman · Pesan · Feed · Pengaturan · Admin (kalau role admin)
```

### Mapping Layar ↔ Sumber Data
| Layar | Sumber utama | Caching |
| --- | --- | --- |
| Home sections | AniList `Page(sort/status)` | provider + image precache |
| Completed doomscroll | AniList `status: FINISHED` paginated | pagination state |
| Jadwal | AniList `airingSchedules` (+ popularity) | per hari |
| Peringkat | AniList popular/trending paginated | pagination state |
| Detail | AniList `Media(id)` | provider |
| **Player** | **Miruro-API self-hosted** (lihat §6.2) | episodes map per anime |
| Riwayat/Library/Settings | Hive lokal | — |
| Sosial/Watch Party/Admin | Supabase (PostgREST + Realtime) | stream |

---

## 4. Arsitektur Teknis

### 4.1 Pendekatan
**Feature-first + Riverpod** (clean-ish lite: repo → provider → screen). Tiap fitur: `data/` + `presentation/`.

### 4.2 Streaming Layer (inti arsitektur)
```
PlayerScreen
   └── streamPayloadsProvider ──► StreamingRepository.fetchPayloads()
          1   Supabase video catalog (admin-curated)        [opsional]
          1.5a MiruroClient  ── AniList ID ──► M3U8 + sub + intro/outro  ★ UTAMA
          1.5b IndoAnimeClient (otakudesu/samehadaku)        [embed → WebView]
          2   YouTube trailer (AniList)                      [fallback]
          3   Mux sample HLS                                 [fallback terakhir]
   └── Payload list → source picker; gagal → failover otomatis → error state terminal
```
- `StreamPayload` membawa `headers` (CDN butuh **Referer** per-stream — tanpa ini 403), subtitle, intro/outro.
- `PlaybackController` adapter menyeragamkan BetterPlayer & YouTube.

### 4.3 Struktur Folder (aktual)
```
lib/
├── main.dart · app.dart
├── core/
│   ├── animation/    # AppAnimations (durasi/curve + reduceMotion)
│   ├── config/       # Env (.env: SUPABASE_*, MIRURO_API_URL, ANIME_API_URL)
│   ├── i18n/         # l10n extension (ARB EN/ID di lib/l10n/)
│   ├── network/      # AniListClient + queries · connectivity provider
│   ├── responsive/ · router/ · settings/ · storage/ (Hive, secure)
│   ├── theme/        # AppColors · AppTypography · AppRadius (token)
│   └── utils/        # haptic, snackbar, nav, number_format (17,2K)
├── features/
│   ├── auth/ · discover/ (home, ranking, section_list) · search/
│   ├── anime_detail/ · player/ (miruro_client, aniskip, overlay)
│   ├── schedule/ · history/ (timeline + item menu) · library/ · favorites/
│   ├── friends/ · messages/ · social/ · watch_party/ · gamification/
│   ├── downloads/ · notifications/ · profile/ · settings/ · legal/ · admin/
│   └── onboarding/ · splash/
└── shared/  # models (Anime, StreamPayload, HistoryEntry) · widgets
             # (AnimeCard, StaggeredItem ber-cap, OfflineBanner, dll.)
```

### 4.4 State Management (Riverpod, contoh kunci)
- `appAuthControllerProvider` — sesi Supabase + user.
- `discoverSectionProvider` (preview) + `paginatedDiscoverProvider` (infinite scroll).
- `streamPayloadsProvider.family` — chain source per (anime, episode).
- `historyChangesProvider` (stream Hive) → `recentWatchedProvider`, `allHistorySortedProvider`, `episodeProgressProvider`.
- `airingScheduleProvider` + `selectedScheduleDayProvider`.
- `appSettingsProvider` — tema, bahasa, autoNext, autoSkip, reduce-motion.

---

## 5. Stack & Dependencies (aktual)

| Kategori | Pilihan | Catatan |
| --- | --- | --- |
| Framework | Flutter 3.x stable · Dart | min SDK 21, target 34 |
| State | `flutter_riverpod` | — |
| Routing | `go_router` | shell route bottom-nav 5 tab |
| Backend | `supabase_flutter` | auth + PostgREST + Realtime (SQL ternumerasi di `sql/`) |
| GraphQL | AniList via `dio` client custom | public, tanpa OAuth |
| Player | `better_player_plus` (HLS) · `youtube_player_flutter` · `webview_flutter` (embed) | overlay kontrol kustom |
| Local | `hive` + `hive_flutter` · `flutter_secure_storage` | history, library, settings |
| Konektivitas | `connectivity_plus` | offline banner |
| UI | `cached_network_image` · `google_fonts` (**bundled offline**, `allowRuntimeFetching=false`) · `lottie` | 19 file font per-weight di `assets/google_fonts/` |
| Lainnya | `share_plus` · `flutter_dotenv` · `url_launcher` | — |
| Test/CI | `flutter_test` · GitHub Actions (analyze + **format gate** + test + build APK) | 61 test hijau |

---

## 6. Strategi API

### 6.1 AniList (GraphQL, public)
- Endpoint `https://graphql.anilist.co` — **tanpa auth** (fitur sync list dihapus).
- Query: trending/popular/topRated/upcoming/**completed** (status FINISHED), search + filter, detail (+ `idMal` untuk AniSkip, `popularity` untuk metrik "views"), airingSchedules (+ popularity), characters, relations.
- Rate limit 90/min → caching provider + debounce search.

### 6.2 Technical Decision: Streaming Source (kronologi)

| Periode | Event | Keputusan |
| --- | --- | --- |
| Mei 2026 awal | `consumet/api.consumet.org` & `aniwatch-api` kena **DMCA** | MVP pakai Sample HLS (Mux) + abstraksi `StreamingRepository` |
| Mei–Juni 2026 | Scraper Indo (wajik/otakudesu/samehadaku) **memblok IP datacenter** → tidak reliable dari cloud | Scraping-from-cloud dinyatakan fundamental tidak andal |
| Juni 2026 | **Miruro-API** (github.com/walterwhite-69/Miruro-API) — Python/FastAPI, **by AniList ID**, balas M3U8 + subtitle + intro/outro; jalan dari datacenter | **Dipilih sebagai sumber utama.** Self-host **gratis di Hugging Face Spaces** (Docker), URL via `MIRURO_API_URL` di `.env` |

**Verifikasi nyata (on-device, Xiaomi Android 14):** stream M3U8 1080p/720p diputar (H.264+AAC), anime sesuai AniList ID. **Catatan teknis penting:**
- CDN upstream (uwucdn/kwik) **mewajibkan header `Referer` per-stream** → diteruskan dari respons Miruro ke ExoPlayer via `StreamPayload.headers` (tanpa ini: HTTP 403).
- HF Space free tier **tidur saat idle** → request pertama ±13 detik (cold start), selanjutnya cepat.
- Sebagian judul balas HTTP 500 (provider upstream kosong) → player **failover otomatis** antar source, lalu error state jelas (bukan retry-loop).
- `.env` di-bundle sebagai asset → **wajib `flutter clean` sebelum build release** agar tidak membawa `.env` basi (insiden: APK lama tanpa `MIRURO_API_URL` jatuh ke mirror Consumet yang mati).

Abstraksi `StreamingRepository` dipertahankan — provider berlisensi tetap bisa di-swap di production tanpa rewrite.

### 6.3 Subtitle & Skip
- Subtitle dari Miruro (multi-bahasa, skip track thumbnails); switcher di player; preferensi Indonesia → English.
- Skip Intro/Outro: timestamp inline Miruro diutamakan, fallback **AniSkip** (by `idMal`); tombol manual + opsi auto-skip di Settings.

---

## 7. UI / Branding (aktual)

| Aspek | Detail |
| --- | --- |
| Nama · Tagline | VibeNime — "Vibe-mu, anime-mu." |
| Primary | `#5DD3F0` (cyan) |
| Secondary | `#FF8FA3` (pink) |
| Surface dark | `#0B0E14` |
| Display font | **Playfair Display** (italic untuk heading/brand) |
| Body font | **Roboto** · Mono: **JetBrains Mono** (angka/stat) — semua **bundled offline** |
| Design tokens | `AppRadius` (4/8/12/16/20/pill — konsolidasi dari 12 nilai ad-hoc) · `AppAnimations` (220/350/400ms, easeOutCubic) |
| Motion | **Ringan by design**: stagger entrance hanya baris pertama Home + cap 6 item; slide subtle 0.10; toggle "Kurangi animasi" (in-app + hormati OS) |
| Tone | Modern, clean, dark-mode-first, ramah wibu |

---

## 8. Status Pengerjaan (per 2026-06-12)

| Fase | Status |
| --- | --- |
| Planning (PRD) | ✅ v2.0 (dokumen ini) |
| Frontend + fitur inti | ✅ 16 area fitur (§2.1) selesai |
| Backend (Supabase SQL + Miruro HF Spaces) | ✅ live & terverifikasi |
| Integrasi + i18n EN/ID | ✅ |
| Testing | ✅ `flutter analyze` 0 issue · **61 test hijau** · CI + format gate aktif |
| Deploy | ✅ **Release APK v1.0.0+1 (72 MB)** terinstal & jalan di device nyata |

**Hutang teknis tercatat (tidak memblok rilis):**
- Pecah `player_screen.dart` (god-file ±1.500 baris) + overlay kosmetik untuk YouTube.
- Spacing tokens (`AppSpacing`) + routing 427 `GoogleFonts.*` → `AppTypography` (ditunda — risiko regresi > manfaat visual).
- Guard spam auth-refresh Supabase saat offline.
- Build release lokal pakai `--no-shrink` (R8 OOM di mesin RAM 7 GB) — di CI/mesin normal bisa minify penuh.

---

## 9. Risiko & Mitigasi (aktual)

| Risiko | Mitigasi |
| --- | --- |
| HF Space tidur (cold start ±13 dtk) | UX loading di player; opsi upgrade tier/cron ping bila perlu |
| Miruro 500 untuk judul tertentu | Failover otomatis antar source + error state + tombol "Lapor episode rusak" |
| CDN ganti kebijakan Referer | Header dibawa per-stream dari respons API (bukan hard-code) |
| `.env` basi di APK | SOP: `flutter clean` sebelum build release + verifikasi `unzip -p apk assets/flutter_assets/.env` |
| AniList rate limit (90/min) | Cache provider, debounce search, pagination 12/halaman |
| Upstream Miruro repo berubah/hilang | Backend di-fork & self-host; abstraksi `StreamingRepository` siap swap |
| Build OOM di mesin kecil | Heap Gradle 2 GB (bukan 8 GB); `--no-shrink` sebagai jalur darurat |

---

## 10. Definition of Done

- [x] `flutter run` sukses di Android (API 34, min 21)
- [x] Register + login Supabase → profil muncul; guest mode jalan
- [x] Home ≥4 section data real AniList + Terakhir Ditonton + Completed doomscroll
- [x] Search + filter genre memunculkan hasil
- [x] Detail: sinopsis, 4 tab, episode list, status picker
- [x] **Player memutar stream nyata (Miruro)** + skip intro/outro + quality + subtitle + failover
- [x] Jadwal Tayang: hari bertanggal + status tayang + prev/next
- [x] Peringkat: All Time + Weekly
- [x] Riwayat: timeline per-tanggal + multi-delete; resume "Lanjut dari menit X"
- [x] Watch Party: 2 device sinkron + chat
- [x] Toggle bahasa EN/ID + tema + reduce-motion
- [x] `flutter analyze` 0 issue · 61 test hijau · CI format gate
- [x] Build APK release sukses & terinstal di device

---

**Dokumen ini adalah living document.** Update bila ada perubahan scope atau keputusan teknis. Untuk panduan setup lengkap (Supabase, Miruro HF Spaces, AniList) lihat `docs/SETUP_GUIDE.md`.
