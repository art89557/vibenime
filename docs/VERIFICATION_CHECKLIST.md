# Checklist Verifikasi — Fitur Baru (Sesi Penyempurnaan)

Semua fitur di bawah sudah lulus `flutter analyze` (0 issue) + `flutter test` (95 pass) +
`flutter build apk --debug`, tapi **belum ter-deploy/diverifikasi visual** karena device
sempat lepas dari USB. Ikuti urutan ini saat HP tersambung.

---

## 0. Prasyarat (sekali)

### 0.1 Jalankan SQL di Supabase (SQL Editor)
Wajib untuk fitur cloud. Tanpa ini, fitur ybs gagal *graceful* (tak crash, cuma tak jalan).
- [ ] `sql/06_watch_history.sql` — sinkron progress nonton lintas device.
- [ ] `sql/07_crash_logs.sql` — crash reporting.

### 0.2 Deploy APK
```bash
# HP tercolok + di-charge (baterai cukup)
<ADB>\adb.exe reconnect
<ADB>\adb.exe devices          # pastikan "skwotckvfayxj78x  device"
<ADB>\adb.exe install -r build/app/outputs/flutter-apk/app-debug.apk
```
> Catatan RAM: pakai **debug build** (no R8). Kalau butuh release → `--no-shrink`.
> `.env` harus punya `SUPABASE_URL` + `SUPABASE_ANON_KEY` untuk cloud sync & crash log.
> `ANIME_API_URL` boleh kosong (default = Sanka Vollerei hosted).

---

## 1. Indo-sub otomatis (Sanka Vollerei) — **paling penting**
- [ ] Buka anime populer → tap **Mulai/Lanjut** → episode play **sub Indonesia** otomatis.
- [ ] Badge source di bawah player = **"Samehadaku"** (atau Otakudesu).
- [ ] Coba beberapa anime dgn judul english≠romaji / ada "Season 2"/":" → tetap ketemu.
- [ ] logcat: minim `🎬 [indo:...] gagal` untuk judul populer.

## 2. Pilihan Bahasa Subtitle (Indo/English) + live
- [ ] Settings → **Bahasa Subtitle** → ganti ke **English**.
- [ ] Player yang sedang terbuka **langsung** ganti ke source Miruro (EN).
- [ ] Buka episode lain → default ikut English (persist).
- [ ] Tap badge source di player → bisa pilih manual (override sementara).

## 3. Ukuran Subtitle (soft-sub / English)
- [ ] Set Bahasa Subtitle = English (biar dapat soft-sub Miruro).
- [ ] Settings → **Ukuran Subtitle** → Small/Medium/Large.
- [ ] Buka episode → ukuran teks subtitle sesuai pilihan.
- [ ] (Indo hardsub tak terpengaruh — subtitle menyatu di video. Ini normal.)

## 4. Gesture player (double-tap seek)
- [ ] **Double-tap sisi kiri** video → mundur 10s + muncul flash "⏪ 10s".
- [ ] **Double-tap sisi kanan** → maju 10s + flash "10s ⏩".
- [ ] **Double-tap tengah** → play/pause.
- [ ] Single-tap tetap toggle kontrol.

## 5. "Lanjutkan Nonton" pintar (Home)
- [ ] Tonton 1 episode sampai selesai → balik Home.
- [ ] Kartu resume tampil **"BERIKUTNYA · EP n+1"** (bukan replay episode tamat).
- [ ] Login → muncul ikon **cloud** kecil (tersinkron) di kartu.

## 6. Cloud sync progress nonton (butuh SQL 06 + login)
- [ ] Login → tonton episode (posisi tersimpan).
- [ ] Cek Supabase tabel `watch_history` → ada row dgn `user_id` benar.
- [ ] (Ideal) reinstall / device kedua → login → Riwayat & posisi resume nyambung.

## 7. For You / "Buat Kamu" (Home)
- [ ] Punya history/favorit beberapa anime → section **"Buat Kamu"** muncul.
- [ ] Subtitle section = "berdasarkan {genre}".
- [ ] User baru (tanpa data) → fallback populer (section tetap berisi).

## 8. Rekomendasi "Kamu mungkin suka" (Detail)
- [ ] Buka Detail anime populer → scroll bawah setelah "Anime Terkait".
- [ ] Muncul row **"Kamu mungkin suka"** (poster + skor) → tap → buka detail.
- [ ] Anime tanpa rekomendasi → section auto-hidden (tak error).

## 9. Download + picker kualitas + browser fallback
- [ ] Detail anime → tap ikon **download**.
- [ ] Muncul bottom-sheet **pilih kualitas** (720p/480p/360p).
- [ ] Kualitas **Pixeldrain** → unduh in-app (progress dialog) → tersimpan offline.
- [ ] Kualitas **host lain** (↗ "via browser") → buka browser untuk unduh.
- [ ] Settings → Penyimpanan → episode tersimpan, bisa diputar offline + hapus.

## 10. Cache AniList offline (#7)
- [ ] Browse trending/detail saat online (isi cache).
- [ ] **Matikan internet** → restart app → buka Home/Detail yang tadi → **tetap tampil** (stale).
- [ ] Search saat offline → tetap boleh gagal (search sengaja tak di-cache).

## 11. Crash reporting (butuh SQL 07 + build **release**)
- [ ] Hanya aktif di build **release** (debug sengaja di-skip).
- [ ] Setelah ada error di app release → cek Supabase tabel `crash_logs` → ada baris.
- [ ] Rate-limited (maks 20/sesi, dedupe) — tak akan banjir.

## 12. Admin (khusus akun super_admin) — light mode + i18n
- [ ] Login admin → Admin Dashboard/Panel.
- [ ] Toggle tema **Terang** (Settings) → layar admin ikut terang (tak gelap rusak).
- [ ] Ganti Bahasa app EN/ID → teks admin ikut ganti.

## 13. Error state konsisten (#8)
- [ ] Matikan internet → buka Pesan/Teman/Aktivitas → tampil **"Tidak ada koneksi"** +
      tombol **Coba lagi** (bukan `Error: <exception>` mentah).

---

## Ringkasan berkas SQL & konfigurasi
| Fitur | SQL | Env |
|---|---|---|
| Cloud sync watch progress | `sql/06_watch_history.sql` | Supabase |
| Crash reporting | `sql/07_crash_logs.sql` | Supabase (+ build release) |
| Indo-sub otomatis | — | `ANIME_API_URL` kosong = Sanka default |
| Sankanime embed (opsional) | — | `SANKANIME_EMBED_TEMPLATE` (kosong = skip) |

## Kalau ada yang gagal
- Indo-sub tak muncul → cek koneksi ke `https://www.sankavollerei.web.id/anime` (bisa
  rate-limit/down); fallback chain (Miruro/YouTube/Mux) tetap jalan; atau set `ANIME_API_URL`
  ke self-host wajik.
- Cloud sync/crash tak tercatat → pastikan SQL sudah di-run + user login + `.env` Supabase benar.
