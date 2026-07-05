# VibeNime — Database Schema

Sumber kebenaran tunggal untuk skema Supabase. Update tiap tambah tabel/kolom.

## Urutan Run Migration

Jalankan di Supabase SQL Editor **berurutan**:

```
00_core.sql        → video_sources, app_config, anime_source_mapping
01_user.sql        → user_profiles (+role/ban/xp/level), user_badges + RPC
02_social.sql      → friendships, direct_messages, activity_events, anime_discussions
03_watchparty.sql  → watch_parties, chat_messages
04_storage.sql     → bucket avatars + banners
05_reports.sql     → episode_reports (laporan episode rusak)
99_seed.sql        → (opsional, dev only) data dummy
```

Setelah run, set super-admin manual:
```sql
UPDATE public.user_profiles SET role = 'super_admin' WHERE user_id = 'YOUR_UUID';
```

## Tabel (12)

| # | Tabel | Domain | Kolom Utama | RLS |
|---|-------|--------|-------------|-----|
| 1 | `video_sources` | core | id, anime_id, episode_number, video_url, priority, source_type | read public, write authenticated (admin) |
| 2 | `app_config` | core | key, value | read public, write service_role |
| 3 | `anime_source_mapping` | core | anilist_id, source, source_slug, confidence | read public, write authenticated |
| 4 | `user_profiles` | user | user_id, username, bio, avatar_url, banner_url, avatar_border, privacy_*, **role**, **banned_at**, **xp**, **level** | read public, write self |
| 5 | `user_badges` | user | user_id, badge_code, earned_at | read public, write via RPC |
| 6 | `friendships` | social | id, requester_id, recipient_id, status (pending/accepted/blocked) | read/write own pairs |
| 7 | `direct_messages` | social | id, sender_id, recipient_id, content, read_at | read/write jika accepted friend |
| 8 | `activity_events` | social | id, user_id, type, anime_id, anime_title, metadata | read friend + self |
| 9 | `anime_discussions` | social | id, anime_id, user_id, content | read public, write authenticated |
| 10 | `watch_parties` | watchparty | id, host_user_id, anime_id, episode_number, position, is_active | read active, write host |
| 11 | `chat_messages` | watchparty | id, party_id, user_id, message, type | read public, write authenticated |
| 12 | `episode_reports` | observability | id, anilist_id, episode_number, source_id, reason, reporter_id, resolved | insert authenticated, read self+admin |

### Storage Buckets (2)
- `avatars` — foto profil (public read, write self folder)
- `banners` — banner profil 1500×500 (public read, write self folder)

## RPC Functions

### User & Auth
- `handle_new_user()` — trigger auto-create user_profiles saat signup
- `get_user_profile(target_id)` — fetch profile by ID
- `search_users_by_username(query)` — search untuk friend (security definer)

### Gamification
- `add_xp(amount)` — tambah XP ke user_profiles, auto-recompute level
- `check_and_award_badges()` — evaluate + award badge sesuai milestone

### Admin (role-gated)
- `admin_set_role(target_id, new_role)` — super_admin only
- `admin_ban_user(target_id, reason)` — admin/super_admin
- `admin_unban_user(target_id)` — admin/super_admin
- `admin_dashboard_stats()` — overview stats global
- `admin_list_users(query, limit, offset)` — paginated user list
- `admin_recent_messages(limit)` — moderation feed
- `admin_delete_message(message_id)` — hapus pesan

## Diagram Relasi

```
auth.users (Supabase managed)
   │ 1:1
   ▼
user_profiles ──────────────┬──────────────┬───────────────┬──────────────┐
  (role, ban, xp, level)    │               │               │              │
   │ 1:many                 │ 1:many        │ 1:many        │ 1:many       │ 1:many
   ▼                        ▼               ▼               ▼              ▼
user_badges          friendships     direct_messages  activity_events  watch_parties
                     (pair)          (pair, friend)   (friend-visible)  (host)
                                                                          │ 1:many
                                                                          ▼
                                                                    chat_messages

video_sources ←── anime_source_mapping (anilist_id → scraper slug)
app_config (key-value runtime config)
anime_discussions (anime_id → comments)
```

## Catatan Optimasi

- **`user_xp` di-merge ke `user_profiles`** (relasi 1:1) — XP + level jadi
  kolom, bukan tabel terpisah. Hilangkan 1 join.
- **`chat_messages` + `direct_messages` SENGAJA terpisah** — Supabase
  `.stream()` realtime cuma support 1 filter `.eq()`. Watch party chat pakai
  `.stream().eq('party_id')`, DM pakai channel pattern. Merge bikin realtime
  watch party butuh refactor besar. Defer.
- **`sql/legacy/`** — arsip 18 file lama (pre-konsolidasi). Bisa dihapus
  setelah migration stabil di production (~1 bulan).

## Riwayat Perubahan

- **v2 (konsolidasi)**: 18 file → 6 numbered files, user_xp merged ke
  user_profiles. Total 11 tabel + 2 bucket.
- **v1**: 12 tabel tersebar di 18 file.
