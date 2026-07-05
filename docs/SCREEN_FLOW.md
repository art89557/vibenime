# VibeNime — Screen Flow

User journey dan navigasi antar screen. Dipakai untuk menyusun **storyboard
demo** dan **flowchart laporan**.

---

## 1. Top-Level Navigation

```
┌─ Splash (boot, 1.2s minimum) ─┐
│                               │
│   Supabase session ada?       │
│   ├── YES ──▶ MainScaffold ──▶ Bottom Nav (5 tabs)
│   └── NO ──▶ Login screen     │
│              ├── Login email/password (existing user)
│              ├── Register (new user)
│              └── "Lanjut tanpa login" (mode tamu, browse only)
└───────────────────────────────┘
```

**Auth Model (v2 Supabase-primary):**
- **Primary**: Supabase email/password — register/login dalam app
- **Optional connector**: AniList OAuth (Profile → Connect) untuk sync My List
- **Mode tamu**: bisa browse + tonton + download, tidak bisa Watch Party / Diskusi / My List
- **Admin role**: gate by `user_metadata.role == 'admin'` (lihat `sql/admin_setup.sql`)

---

## 2. Bottom Navigation (5 tabs)

```
┌──────────┬────────┬─────────┬──────────┬─────────┐
│   Home   │ Search │ Library │ Schedule │ Profile │
└──────────┴────────┴─────────┴──────────┴─────────┘
     │         │        │         │           │
     ▼         ▼        ▼         ▼           ▼
   Hero +   Genre +   My List   Hari +     Settings
   Trending  Result   + Sedang  Anime per  + Logout
   carousel  grid     Ditonton  hari        + About
```

---

## 3. Discovery → Detail → Player Flow

```
[Home/Search]
     │
     │ tap AnimeCard
     ▼
[AnimeDetailScreen]
     │ ├── Hero Banner (cover + bookmark)
     │ ├── 3 Metric Cards (rating, episode, durasi)
     │ ├── Genre chips
     │ ├── "Tonton Sekarang" button
     │ ├── Pesta Nonton card (NEW — Phase 2)
     │ ├── Tabs: Episode / Sinopsis / Karakter / Diskusi
     │ └── Anime Terkait (relations)
     │
     │ tap episode
     ▼
[PlayerScreen]
     │ ├── Multi-source fallback chain
     │ ├── better_player atau youtube_player
     │ ├── Source badge (X/Y · fallback?)
     │ ├── Synopsis snippet
     │ └── Episode picker grid
     │
     │ progress saved tiap 5 detik → Hive
     ▼
[Back to Home → "Lanjutkan" big card muncul]
```

---

## 4. Watch Party Flow (Phase 2)

```
[AnimeDetailScreen — Pesta Nonton card]
     │
     ├─ HOST: "Mulai Pesta Nonton"
     │     │
     │     │ AppUser logged in?
     │     ├── NO  → redirect /login
     │     └── YES → repo.createParty()
     │              │
     │              ▼
     │      [WatchPartyScreen — Host mode]
     │       ├─ Header "Anda Host" + count
     │       ├─ YoutubePlayer (full controls)
     │       ├─ Timer 2s → broadcast position
     │       └─ ChatOverlay (input enabled)
     │              │
     │              │ tap "Akhiri pesta"
     │              ▼
     │       repo.endParty() → is_active=false
     │
     └─ VIEWER: tap party tile "Gabung"
           │
           ▼
      [WatchPartyScreen — Viewer mode]
       ├─ Header "Pesta @host" + count
       ├─ YoutubePlayer (controls hidden)
       ├─ Listen partyStream → diff > 3s? seek
       └─ ChatOverlay (login Supabase to chat)
              │
              │ host endParty → stream emits
              ▼
       _PartyEndedView (back to detail)
```

---

## 5. Admin Flow (Bulk Insert)

```
[Admin tab di Profile (require Supabase auth)]
     │
     ▼
[AdminListScreen — semua VideoSource]
     │ FAB: + New
     │ Long-press: edit / delete
     ▼
[AdminFormScreen — single source CRUD]
   atau
[AdminBulkScreen — bulk insert]
     │ Mode toggle: Pattern / Paste List
     │
     ├── Pattern: URL template + range from-to
     │   "https://archive.org/.../E{ep:03d}.mp4" 1-12
     │   → generate 12 URLs
     │
     ├── Paste List: multi-line text
     │   skip komentar (#) dan baris kosong
     │
     ▼
   Insert ke video_sources (priority auto-set)
```

---

## 6. State Persistence

| State | Storage | TTL |
| --- | --- | --- |
| AniList token | flutter_secure_storage | sampai logout |
| Supabase session | shared_preferences (auto) | sampai signOut |
| Watch history | Hive box `history` | unlimited |
| My List | Hive box `my_list` | unlimited |
| Image cache | CachedNetworkImage | 7 hari (default) |
| Scroll position | PageStorageBucket (Home) | session |

---

## 7. Error & Empty States

| Scenario | Penanganan |
| --- | --- |
| AniList API error | `ErrorRetry` widget dengan tombol retry |
| Supabase fetchSources fail | Silent fallback ke const [] (debug log) |
| Player source error | Auto-fallback ke source berikutnya |
| Empty My List | Empty state ilustrasi + CTA "Cari anime" |
| Search no result | Empty state + saran genre |
| Watch party stale | Auto-detect via `isStale` getter (>30 detik) |
| Login required (host) | Snackbar info + redirect /login |

---

## 8. Deep Link Routes

Semua route registered di `lib/core/router/app_routes.dart`:

```dart
/                            // Splash → cek Supabase session
/login                       // Supabase email/password form
/register                    // Supabase signup form
/home, /search, /library     // Bottom nav tabs
/schedule, /profile          // Bottom nav tabs
/settings, /genre            // Out-of-shell
/admin                       // Source list (gated isAdmin)
/admin/new                   // Create form
/admin/edit                  // Edit form
/admin/bulk                  // Bulk insert
/anime/:id                   // Detail
/player/:animeId/:episodeId  // Player
/watch-party/:partyId        // Real-time party + presence
```
