# Cara Tambah Video Anime via YouTube (Muse Asia / Ani-One Asia)

> Sumber legal & gratis untuk full episode anime modern.
> Dipakai sebagai alternatif Cloudflare Stream / Internet Archive.

---

## Latar Belakang

Per Mei 2026, semua API publik scraper anime sudah kena DMCA / shutdown:
- ❌ Consumet, aniwatch-api, amvstrm public — semua mati
- ✅ **YouTube channel resmi** dari publisher Jepang masih hidup

**Channel resmi yang upload anime full episode untuk SE Asia:**

| Channel | URL | Konten |
| --- | --- | --- |
| **Muse Asia / Muse Indonesia** | https://www.youtube.com/@MuseIndonesia | Banyak anime modern, sub Indonesia |
| **Ani-One Asia** | https://www.youtube.com/@Ani-OneAsia | Berbagai anime, sub English/Chinese |
| **AniPlus Asia** | https://www.youtube.com/@AniPlusAsia | Simulcast anime musim ini |
| **Animax Asia** | https://www.youtube.com/@AnimaxAsia | Catalog anime klasik |

VibeNime sekarang punya `source_type: youtube` di admin panel — Anda bisa tambah video apa saja dari channel ini.

---

## Step-by-Step

### 1. Cari Anime di AniList Dulu

Untuk mendapatkan **AniList ID** anime yang ingin Anda tambah:

1. Buka https://anilist.co
2. Search nama anime, mis. "Spy x Family"
3. Klik anime yang sesuai → URL menjadi `https://anilist.co/anime/140960/...`
4. ID = **140960** (catat angka ini)

### 2. Cari Video di YouTube Muse Asia

1. Buka https://www.youtube.com/@MuseIndonesia/videos
2. Search judul anime, mis. **"Spy x Family"**
3. Pilih episode yang Anda inginkan
4. Buka video → copy URL dari address bar:
   ```
   https://www.youtube.com/watch?v=dQw4w9WgXcQ
   ```

### 3. Buka Admin Panel di App

1. Buka VibeNime di HP
2. **Saya** tab → ⚙ **Settings**
3. Section **ADMIN** → tap **Admin Panel**
4. Login pakai email Supabase Anda
5. Tap **+ Tambah** (kanan bawah)

### 4. Isi Form

| Field | Isi dengan |
| --- | --- |
| **AniList ID** | `140960` (Spy x Family) |
| **Episode Number** | `1` |
| **Source Type** | `youtube` ⭐ |
| **Video URL** | `https://www.youtube.com/watch?v=dQw4w9WgXcQ` |
| **Quality** | Pilih sesuai (480p / 720p / 1080p) |
| **Language** | `id` (Indonesia) atau `en` |
| **Subtitle URL** | Kosongkan (YouTube punya CC native) |
| **Notes** | `Spy x Family — EP 1 (Muse Indonesia)` |

Tap **Save**. Selesai!

### 5. Test di App

1. Tutup admin panel
2. Tab **Beranda** atau **Cari** → cari "Spy x Family"
3. Tap card → **Detail** muncul
4. Tap **Episode 1**
5. **Player buka — video YouTube Muse Asia full episode play!** 🎉

---

## Tips & Trik

### Bulk Insert via SQL
Kalau punya banyak video, lebih cepat insert via Supabase SQL Editor:

```sql
INSERT INTO video_sources
  (anilist_id, episode_number, video_url, language, quality, source_type, notes)
VALUES
  (140960, 1, 'https://youtube.com/watch?v=ABC123', 'id', '720p', 'youtube', 'Spy x Family EP 1'),
  (140960, 2, 'https://youtube.com/watch?v=DEF456', 'id', '720p', 'youtube', 'Spy x Family EP 2'),
  (140960, 3, 'https://youtube.com/watch?v=GHI789', 'id', '720p', 'youtube', 'Spy x Family EP 3');
```

### Format URL yang Didukung

App auto-extract video ID dari format ini:
- ✅ `https://www.youtube.com/watch?v=ABC123`
- ✅ `https://youtu.be/ABC123`
- ✅ `https://www.youtube.com/embed/ABC123`
- ✅ `https://m.youtube.com/watch?v=ABC123`
- ✅ `https://www.youtube.com/shorts/ABC123`
- ✅ Cuma video ID: `ABC123` (11 karakter)

### Anime yang Sering Tersedia di Muse Indonesia
- Spy x Family
- Frieren: Beyond Journey's End
- The Apothecary Diaries
- Demon Slayer (beberapa episode)
- That Time I Got Reincarnated as a Slime
- Mushoku Tensei
- Mashle
- Sengoku Youko
- Solo Leveling
- Dan banyak lagi (~ratusan judul)

### Region & Geo-Block
Muse Indonesia targeting SE Asia. Beberapa video bisa kena geo-block kalau:
- App di-akses dari luar SE Asia
- VPN aktif

Solusi: pastikan koneksi normal Indonesia.

---

## Limitasi

| Aspek | Catatan |
| --- | --- |
| Bandwidth | YouTube CDN — sangat reliable |
| Quality | Adaptive (auto), tidak bisa force 4K kalau source tidak ada |
| Subtitle | YouTube CC native (bukan dari `subtitle_url` field) |
| Download offline | Tidak bisa (YouTube TOS) |
| Embed restriction | ~30% anime trailer kena Error 150, tapi **full episode upload Muse jarang kena** |
| Iklan | Akan muncul iklan YouTube di awal & tengah video |

---

## Troubleshooting

### Video tidak play di app
1. Cek URL: pastikan video ID valid (11 karakter)
2. Coba buka di browser dulu — verifikasi tidak geo-block
3. Coba cabut dan paste ulang URL di admin form

### Error "Playback on other apps disabled"
- Beberapa video punya embed restriction
- Coba video lain dari channel sama
- Atau pakai source_type lain (Internet Archive / sample)

### Quality dropdown tidak ngaruh
- YouTube selalu adaptive bitrate
- Quality field di form cuma label/info — actual quality dipilih YouTube otomatis sesuai bandwidth

---

## Roadmap

Future improvement (post-tugas):
- [ ] YouTube Data API integration → search Muse Indonesia automatically
- [ ] Auto-detect channel uploads baru → notify admin
- [ ] Cache YouTube video metadata di Supabase

Untuk sekarang, manual workflow seperti di atas sudah cukup untuk demo & MVP.
