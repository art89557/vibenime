# Penerapan 8 Golden Rules of Interface Design di VibeNime

> **Sumber teori**: Ben Shneiderman, *Designing the User Interface: Strategies
> for Effective Human-Computer Interaction* (6th ed., 2017).
>
> Dokumen ini memetakan setiap rule ke implementasi konkret di codebase
> VibeNime, lengkap dengan path file & contoh kode untuk laporan tugas.

---

## Konsep & Relevansi

8 Golden Rules adalah seperangkat prinsip desain interaksi yang membantu
membangun aplikasi yang **mudah dipahami, sulit untuk salah, dan menyenangkan
digunakan**. Walau dikemukakan di era desktop, prinsip-prinsipnya tetap
relevan — bahkan **lebih kritis** — di mobile karena layar kecil + input
sentuhan menambah ambiguitas.

VibeNime menerapkan ke-8 rule ini di berbagai layar (Discover, Search,
Detail, Player, Pustaka, Saya, Pengaturan, Admin Panel).

---

## Rule 1 — Strive for Consistency

> **Definisi**: Gunakan urutan aksi konsisten, terminologi konsisten di
> menu/prompt/help, layout & color konsisten di seluruh aplikasi.

**Penerapan di VibeNime:**

### 1.1 Single Source of Truth untuk Tema
File: [`lib/core/theme/app_colors.dart`](../lib/core/theme/app_colors.dart),
[`lib/core/theme/app_theme.dart`](../lib/core/theme/app_theme.dart)

- 1 palet warna global (cyan `#5DD3F0`, surface `#0B0E14`, dll) — dipakai di
  14+ file action button, badge, link.
- 3 font family konsisten:
  - **DM Serif Display Italic** — semua headline ("vibe apa hari ini?", "Cari sesuatu —")
  - **Inter** — body text & button label
  - **JetBrains Mono** — small uppercase labels & numeric data

### 1.2 Layout Pattern Repeat
- Semua section di Home/Pustaka/Saya pakai pattern `SectionHeader` widget yang sama
  (file: `lib/shared/widgets/section_header.dart`)
- Setiap card poster anime pakai `AnimeCard` (`lib/shared/widgets/anime_card.dart`)
  dengan aspect ratio 2:3, font size, padding identik

### 1.3 Konstanta Magic Numbers
File: [`lib/core/config/constants.dart`](../lib/core/config/constants.dart)

Konstanta seperti `searchDebounce: 350ms`, `discoverCacheTtl: 30min`,
`defaultSourcePriority: 100` di-extract supaya **consistent across app** dan
mudah di-tweak.

---

## Rule 2 — Seek Universal Usability

> **Definisi**: Cater ke pengguna beragam — pemula vs ahli, accessibility,
> perbedaan device.

**Penerapan di VibeNime:**

### 2.1 Mode Tamu (Guest Mode)
File: `lib/features/auth/presentation/login_screen.dart` line 78

User pemula yang **belum punya AniList account** bisa pakai aplikasi penuh
tanpa harus signup. Beberapa fitur (My List sync) di-gate, tapi browsing,
search, watch — semua jalan.

### 2.2 Toggle Mode Bulk Insert
File: `lib/features/admin/presentation/admin_bulk_screen.dart`

Admin pemula bisa pakai mode **"Paste List"** (paling simple, tinggal copy-paste URL).
Admin ahli bisa pakai mode **"Pattern"** dengan placeholder `{ep:03d}` untuk
generate puluhan URL sekaligus dari satu pattern.

### 2.3 Multiple Source Type
File: `lib/core/utils/source_type.dart`

Mendukung 5 jenis source: Internet Archive, Cloudflare R2, Mux, YouTube, manual.
User bisa pilih sesuai konteks pengetahuan & kebutuhan.

---

## Rule 3 — Offer Informative Feedback

> **Definisi**: Untuk setiap aksi user, sistem harus memberikan respons.
> Aksi sering = feedback ringan; aksi jarang/serius = feedback substansial.

**Penerapan di VibeNime:**

### 3.1 Haptic Feedback
File: [`lib/core/utils/haptic_helper.dart`](../lib/core/utils/haptic_helper.dart)

3 tingkat haptic feedback:
- `Haptic.light()` — button tap biasa
- `Haptic.medium()` — save/submit (mis. admin form save)
- `Haptic.heavy()` — destructive/error (mis. delete confirmation)

Implementasi di:
- `admin_form_screen.dart` line 168 (save) — `Haptic.medium()`
- `admin_form_screen.dart` line 244 (delete) — `Haptic.heavy()`

### 3.2 Styled Snackbar
File: [`lib/core/utils/snackbar_helper.dart`](../lib/core/utils/snackbar_helper.dart)

Replace plain `SnackBar` dengan `AppSnackbar`:
- `AppSnackbar.success()` → cyan background + check icon ✓
- `AppSnackbar.error()` → red background + error icon
- `AppSnackbar.undoable()` → bisa di-undo dalam 5 detik

### 3.3 Loading State Berbeda per Konteks
- Discover: **Shimmer skeleton** (mock card + animasi gradient)
- Search: **Shimmer grid**
- Player: **Spinner + descriptive message** ("Memuat dari Supabase...")
- Admin form auto-fetch anime: **Spinner kecil + "Mencari di AniList…"**

### 3.4 Source Badge di Player
File: `lib/features/player/presentation/player_screen.dart` line 268

Player display badge "🎬 YouTube · Source 1/3" supaya user tahu **source mana**
yang sedang diputar dan **berapa fallback** tersedia. Saat fallback ke source
lain, badge update otomatis.

---

## Rule 4 — Design Dialogs to Yield Closure

> **Definisi**: Aksi user harus punya beginning, middle, end yang jelas.
> Memberi kepuasan & sinyal "selesai" ke user.

**Penerapan di VibeNime:**

### 4.1 Login Flow
File: `lib/features/auth/presentation/login_screen.dart`

1. **Begin**: Tap "Login with AniList" → muncul WebView Supabase OAuth
2. **Middle**: User input credentials di halaman AniList
3. **End**: WebView pop dengan token → app navigate ke Home dengan
   greeting "Halo, @username 👋"

### 4.2 Add to List Flow
File: `lib/features/anime_detail/presentation/add_to_list_sheet.dart`

1. **Begin**: Tap FAB "Add to List" di Detail screen
2. **Middle**: Bottom sheet muncul dengan 5 status pilihan
3. **End**: Pilih status → loading spinner → snackbar "Ditambahkan ke
   'Plan to Watch'" + tombol Urungkan

### 4.3 Bulk Insert Flow
File: `lib/features/admin/presentation/admin_bulk_screen.dart`

1. **Begin**: Tap icon `playlist_add` di Admin app bar
2. **Middle**: Isi pattern/list, tap **Preview**
3. **Closure 1** (preview): list URL ter-generate, user verifikasi
4. **Middle 2**: Tap **Generate N Entries**
5. **End**: Snackbar "5 video tersimpan" + auto pop ke admin list

---

## Rule 5 — Prevent Errors

> **Definisi**: Desain UI sehingga user tidak bisa membuat kesalahan serius.
> Kalau salah, sistem harus mendeteksi dan menawarkan instruksi pembetulan
> yang sederhana.

**Penerapan di VibeNime:**

### 5.1 Real-time URL Validation
File: `lib/features/admin/presentation/admin_form_screen.dart` line 100

Saat user mengetik di field "Video URL", listener `_onVideoUrlChanged()`
memvalidasi:
- Untuk `source_type=youtube` → cek bisa di-extract video ID via `extractYoutubeId()`
- Untuk source lain → cek scheme `http://` atau `https://`

Suffix icon di TextField:
- **✓ cyan** kalau valid
- **⚠️ orange** kalau invalid

User langsung tahu sebelum tap Save.

### 5.2 Range Validation di Bulk Insert
File: `lib/features/admin/presentation/widgets/url_pattern_helper.dart` line 25

`generatePatternUrls()` throw `FormatException` kalau:
- Pattern tidak mengandung `{ep}` placeholder → "Pattern harus mengandung {ep}..."
- `from > to` → "Episode 'from' (5) > 'to' (1)"
- Range > 200 → "Range terlalu besar. Max 200 per batch."

### 5.3 Konfirmasi Dialog Sebelum Destructive
File: `lib/features/admin/presentation/admin_form_screen.dart` line 215

Sebelum delete video, muncul `AlertDialog` "Hapus Video? Aksi ini tidak bisa
di-undo." dengan pilihan **Batal** (default focus) & **Hapus** (destructive
red).

### 5.4 Auto-Fallback Player saat Source Error
File: `lib/features/player/presentation/player_screen.dart`

Kalau YouTube embed di-block (Error 150), player **otomatis switch** ke
source berikutnya tanpa user perlu tap retry. Sistem mendeteksi error,
menawarkan source alternatif.

---

## Rule 6 — Permit Easy Reversal of Actions

> **Definisi**: User harus bisa undo aksi mereka. Bermanfaat juga untuk
> ekspolasi (mengurangi anxiety mencoba fitur baru).

**Penerapan di VibeNime:**

### 6.1 Undo Snackbar untuk Add to List
File: `lib/features/anime_detail/presentation/add_to_list_sheet.dart` line 75

Setelah user add anime ke list, snackbar muncul **5 detik** dengan tombol
"Urungkan". Tap → status anime di-set ke `DROPPED` (soft remove di AniList).

### 6.2 Undo Snackbar untuk Delete Video Admin
File: `lib/features/admin/presentation/admin_form_screen.dart` line 250

Setelah delete video di admin panel, snackbar dengan "Urungkan" muncul.
Tap → re-insert video dengan data yang sama (priority, source, dll).

### 6.3 Back Button Konsisten
Setiap screen punya back button di top-left (kecuali Home tab — root).
User selalu bisa kembali ke layar sebelumnya tanpa kehilangan state.

### 6.4 Cancel di Modal/Dialog
Setiap dialog konfirmasi punya tombol **Batal** sebagai default focus.
Bottom sheet bisa di-dismiss dengan swipe down.

---

## Rule 7 — Keep Users in Control (Internal Locus of Control)

> **Definisi**: User harus merasa **mereka** yang menginisiasi aksi, bukan
> sebaliknya. Hindari surprise modal, auto-action tanpa consent.

**Penerapan di VibeNime:**

### 7.1 Manual Initiate untuk Setiap Aksi Penting
- Login: button explicit, bukan auto-prompt
- Search: user mengetik, bukan auto-suggest popup
- Add to List: tap FAB, bukan auto-add saat detail dibuka

### 7.2 Splash Auto-Redirect Bisa Di-Cancel
File: `lib/features/splash/presentation/splash_screen.dart`

Splash 1.2 detik display, lalu auto-navigate. Tapi user bisa tap back button
untuk skip ke Login langsung — tidak terkunci.

### 7.3 Admin Mode Eksplisit
Admin Panel di-akses lewat path **eksplisit** (Settings → Admin Panel) +
butuh login Supabase terpisah. Tidak ada admin mode tersembunyi yang aktif
otomatis.

### 7.4 Theme Tetap (No Auto-Switch)
App selalu dark mode. Tidak switch otomatis ke light berdasarkan time-of-day
atau system preference (yang bisa membingungkan).

---

## Rule 8 — Reduce Short-term Memory Load

> **Definisi**: Manusia hanya bisa ingat ~7 item di working memory. UI harus
> minimize beban memori dengan: display info penting, tools yang jelas,
> recall > recognition.

**Penerapan di VibeNime:**

### 8.1 Continue Watching di Home
File: `lib/features/discover/presentation/home_screen.dart`

User tidak perlu ingat "tadi nonton sampe episode berapa?" — Big resume card
di Home menampilkan: judul, episode, posisi (`14:32 / 24:00`), progress bar.

### 8.2 Recent Searches
File: `lib/features/search/presentation/search_screen.dart` line 156

Section "TERAKHIR DICARI" di Search screen — user tidak perlu ingat keyword
yang dicari sebelumnya.

### 8.3 Trending di Indonesia
File: `lib/features/search/presentation/search_screen.dart` line 199

"Trending di Indonesia" section memberikan **suggestion** bukan minta user
ingat apa yang harus di-search.

### 8.4 Auto-Fetch Anime Title di Admin Form ⭐
File: `lib/features/admin/presentation/admin_form_screen.dart` line 119

Saat admin input AniList ID (mis. `4082`), app **otomatis fetch** dari
AniList dan tampilkan badge:
> **✓ Tetsuwan Atom · TV · 104 eps**

Admin tidak perlu ingat "ID 4082 itu anime apa". Mengurangi cognitive load
secara signifikan saat seed banyak data.

### 8.5 Source Badge di Player
File: `lib/features/player/presentation/player_screen.dart`

Player menampilkan "Source 2/3 (fallback)" — user tidak perlu ingat berapa
source tersedia atau yang mana yang sedang diputar.

### 8.6 Episode Progress Bar Visual
File: `lib/features/library/presentation/widgets/sedang_ditonton_card.dart`

Card "Sedang ditonton" menampilkan **progress bar visual** (cyan), bukan
hanya teks "5 dari 12 episode". Persepsi visual = recognition (lebih cepat
dari recall).

---

## Ringkasan

| # | Rule | Status di VibeNime | Bukti Utama |
|---|---|---|---|
| 1 | Consistency | ✅ Fully | `app_theme.dart`, `constants.dart` |
| 2 | Universal usability | ✅ Implemented | Guest mode, toggle bulk mode |
| 3 | Informative feedback | ✅ Fully | `haptic_helper.dart`, `snackbar_helper.dart`, source badge |
| 4 | Yield closure | ✅ Implemented | Login/Add/Bulk flow ada akhir jelas |
| 5 | Prevent errors | ✅ Fully | Real-time URL validation, range check, confirm dialog |
| 6 | Easy reversal | ✅ Fully | Undo snackbar untuk add list & delete video |
| 7 | Locus of control | ✅ Fully | Manual init, no auto-action |
| 8 | Reduce memory load | ✅ Fully | Continue watching, recent search, auto-fetch title |

**8/8 rules diterapkan dengan bukti konkret.**

---

## Untuk Laporan Tugas

Cara pakai dokumen ini:

1. **Section "Implementasi UX" laporan**: paste ringkasan + 1-2 detail per rule
2. **Lampiran**: paste full dokumen sebagai bukti penerapan
3. **Screenshot**: ambil screen yang menampilkan badge anime preview
   (Rule 8), undo snackbar (Rule 6), URL validation icon (Rule 5)
4. **Code reference**: laporan teknis bisa cite file path + line number
