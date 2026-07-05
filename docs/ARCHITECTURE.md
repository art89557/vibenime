# VibeNime — Arsitektur Aplikasi

Dokumentasi arsitektur high-level untuk laporan tugas. Fokus ke **layer
boundaries**, **data flow**, dan **dependency direction**.

---

## 1. Diagram Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                    Presentation Layer (UI)                      │
│  ┌─────────┐ ┌────────┐ ┌───────┐ ┌──────────┐ ┌──────────────┐ │
│  │Discover │ │ Detail │ │Player │ │ Library  │ │ Watch Party  │ │
│  └────┬────┘ └───┬────┘ └───┬───┘ └────┬─────┘ └──────┬───────┘ │
│       │          │          │          │              │        │
│       └──────────┴──────────┴──────────┴──────────────┘        │
│                            │                                   │
│                  Riverpod Providers                            │
└─────────────────────────────┬───────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────┐
│                Data Layer (Repositories)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │AnimeRepo     │  │StreamingRepo │  │WatchPartyRepo          │ │
│  │(GraphQL)     │  │(3-layer fb)  │  │(Supabase Realtime)     │ │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬─────────────┘ │
│         │                  │                    │                │
└─────────┼──────────────────┼────────────────────┼────────────────┘
          │                  │                    │
          ▼                  ▼                    ▼
   ┌───────────┐      ┌───────────────┐    ┌─────────────────┐
   │ AniList   │      │ Supabase      │    │ Hive (Local)    │
   │ GraphQL   │      │ - video_src   │    │ - history       │
   │ - metadata│      │ - watch_parties│   │ - my_list       │
   │ - trailer │      │ - chat_msg    │    └─────────────────┘
   └───────────┘      └───────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ Realtime CDC │
                    │ (Postgres)   │
                    └──────────────┘
```

---

## 2. Pilar Teknologi

| Layer | Teknologi | Alasan |
| --- | --- | --- |
| UI | Flutter 3.41 + Material 3 | Single codebase Android/iOS |
| State | Riverpod 2.6 | Compile-time safe, testable |
| Routing | go_router 14.6 | Deep link + ShellRoute bottom nav |
| Metadata | AniList GraphQL | Free, lengkap, public domain — optional connector |
| Auth User | **Supabase email/password** | Primary auth, app-native register/login |
| Auth Role | `user_metadata.role` | Admin gating (`'admin'` vs null) |
| AniList Sync | OAuth Implicit Grant (opsional) | Connect via Profile untuk sync My List |
| Database | Supabase Postgres | Free 500 MB + RLS |
| Realtime | Supabase Realtime CDC + Presence | Postgres change events + viewer presence channel |
| Storage Lokal | Hive | NoSQL ringan untuk history |
| Player HLS | better_player_plus | HLS multi-bitrate + subtitle |
| Player YT | youtube_player_flutter | Embed Muse Asia, Ani-One |

---

## 3. Multi-Source Streaming Fallback

VideoSource layer (di Supabase) di-rank by `priority` (lower = higher).
Player iterate list dari index 0; on error → next source.

```
priority 50  → Internet Archive (.mp4, classic anime public domain)
priority 100 → YouTube full episode (Muse Asia, Ani-One Asia)
priority 150 → AniList trailer (15-90 detik preview)
priority 200 → Mux test stream (HLS sample, last resort)
```

Implementasi: `lib/features/player/data/streaming_repository.dart`
build payloads list, player consume sequentially via state index.

---

## 4. Watch Party — Real-time Sync

Critical flow real-time nonton bareng:

```
[Host Phone]                     [Supabase]                   [Viewer Phone]
     │                                │                              │
     │── createParty(animeId) ──────▶│                              │
     │◀── party.id ──────────────────│                              │
     │                                │                              │
     │── timer 2s tick ──┐            │                              │
     │  updatePlayback   │            │                              │
     │  (pos, isPlaying)─┴──────────▶│── Postgres CDC ─────────────▶│
     │                                │                              │  watch
     │                                │                              │  diff > 3s?
     │                                │                              │  → seekTo
     │                                │                              │
     │── chat: sendMessage ─────────▶│── INSERT chat_messages ─────▶│
     │                                │                              │  display
     │                                │                              │  bubble
     │                                │                              │
     │── endParty ───────────────────▶│  is_active = false           │
     │                                │── stream completion ────────▶│  show
     │                                │                              │  ended
```

**RLS policies** memastikan:
- Hanya host yang bisa update `watch_parties` (auth.uid = host_user_id)
- Authenticated user bisa insert chat_messages dengan `user_id = auth.uid()`
- Anyone bisa read active parties (untuk discoverability)
- User bisa delete chat_messages sendiri

**Participant Presence (v2):**
- Setiap viewer subscribe ke Realtime channel `party_{partyId}` via
  `WatchPartyPresence` wrapper
- `RealtimeChannel.track({viewer_id, username})` saat masuk screen
- Count auto-update via `onPresenceSync` callback — UI di-render dengan
  `StreamBuilder<int>` di header
- Auto-cleanup saat disconnect / app close (no manual decrement needed)

---

## 5. Folder Structure

```
lib/
├── core/                   # Shared infra (theme, router, utils, config)
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── app_auth_repository.dart   # Supabase email/password (PRIMARY)
│   │   │   └── auth_repository.dart        # AniList OAuth (optional sync)
│   │   └── presentation/
│   │       ├── app_auth_controller.dart    # AppAuthState StateNotifier
│   │       ├── login_screen.dart           # Supabase email/password form
│   │       ├── register_screen.dart        # Supabase signup form
│   │       └── auth_webview_screen.dart    # AniList OAuth WebView
│   ├── admin/              # Bulk insert + CRUD video_sources (gated isAdmin)
│   ├── discover/           # Home + categories + search
│   ├── anime_detail/       # Detail screen + episode list + diskusi
│   ├── player/             # Multi-source player + history + download
│   ├── downloads/          # DownloadRepository + offline playback
│   ├── watch_party/        # Real-time nonton bareng + presence
│   ├── library/            # My List + Sedang Ditonton + offline section
│   ├── schedule/           # Jadwal mingguan
│   ├── profile/            # Settings + AniList connect + logout
│   └── splash/             # App boot — cek Supabase session
├── shared/                 # Cross-feature widgets + models
└── app.dart                # Root MaterialApp + theme

sql/                        # Database migrations + RLS
docs/                       # Dokumentasi tugas (8 Golden Rules, dll)
test/                       # Unit + widget tests
```

---

## 6. Data Flow Pattern

Setiap feature mengikuti pattern yang sama:

```
UI (StatelessWidget/ConsumerWidget)
    └─ ref.watch(provider)
        └─ provider depends on Repository
            └─ Repository talks to External (HTTP/Supabase/Hive)
                └─ Returns Domain Model (immutable)
                    └─ UI rebuilds via AsyncValue.when()
```

**Tidak ada** business logic di widget. Semua side-effect di repository.
Provider sebagai **dependency injection** + **caching**.

---

## 7. Test Strategy

| Layer | Testing approach |
| --- | --- |
| Domain models | Unit test parsing JSON + getter logic |
| Utility helpers | Unit test pure functions (regex, format, dll) |
| Widgets | Widget test dengan `pumpWidget` + asserts |
| Repository | Skipped (integration heavy — manual QA via app) |
| Realtime sync | Manual multi-device QA (verifikasi Phase 2) |

Target coverage: critical paths dijamin oleh `flutter test`.

---

## 8. Security Considerations

- **Token AniList** disimpan di `flutter_secure_storage` (Keystore/Keychain)
- **RLS Supabase** enforce di database level — client tidak bisa bypass
- **`.env`** di-include via asset untuk runtime (ANON key only — Service
  role key tidak pernah ada di client)
- **YouTube embed** pakai sandbox iframe — tidak bisa akses parent context
