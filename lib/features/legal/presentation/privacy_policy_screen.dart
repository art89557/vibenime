import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav_helper.dart';

/// Privacy Policy — wajib untuk Play Store submission.
///
/// Konten singkat (Indonesia) menjelaskan data apa yang dikumpulkan,
/// tujuan, retensi, dan hak user. Mengikuti format ringkas Termly.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kebijakan Privasi VibeNime',
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Terakhir diperbarui: 17 Mei 2026',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 24),

            _Section(
              title: '1. Pendahuluan',
              body:
                  'VibeNime ("kami") menghargai privasi Anda. Kebijakan ini '
                  'menjelaskan data yang kami kumpulkan saat Anda menggunakan '
                  'aplikasi, cara penggunaannya, dan hak Anda atas data tersebut.',
            ),
            _Section(
              title: '2. Data yang Dikumpulkan',
              body:
                  '• **Akun**: email, username, dan password (di-hash). '
                  'Disimpan di Supabase.\n'
                  '• **Aktivitas**: riwayat tontonan, daftar favorit, hasil '
                  'pencarian — disimpan lokal di perangkat (Hive) dan '
                  'opsional disinkron ke akun Anda.\n'
                  '• **Watch Party**: pesan chat, status reaksi, dan nama '
                  'tampilan saat Anda gabung party.\n'
                  '• **Crash diagnostics**: jika terjadi error, Sentry mencatat '
                  'stacktrace + device info (anonim) untuk perbaikan bug.',
            ),
            _Section(
              title: '3. Tujuan Penggunaan',
              body:
                  '• Memberikan akses streaming dan fitur sosial.\n'
                  '• Menyimpan preferensi dan riwayat untuk personalisasi.\n'
                  '• Mendiagnosis dan memperbaiki bug aplikasi.\n'
                  '• Kami **TIDAK** menjual data Anda ke pihak ketiga.',
            ),
            _Section(
              title: '4. Pihak Ketiga',
              body:
                  '• **AniList**: metadata anime (judul, sinopsis, cover) — '
                  'data publik, tidak ada PII.\n'
                  '• **Supabase**: backend storage akun dan watch party.\n'
                  '• **Sentry**: crash reporting (anonim).\n'
                  '• **Google Play Services**: install/uninstall metrics.',
            ),
            _Section(
              title: '5. Retensi Data',
              body:
                  'Data akun disimpan selama akun aktif. Anda dapat menghapus '
                  'akun kapan saja melalui Settings → Hapus Akun. Data lokal '
                  '(history, downloads) terhapus saat uninstall.',
            ),
            _Section(
              title: '6. Hak Anda',
              body:
                  'Anda berhak: (a) mengakses data Anda, (b) memperbarui '
                  'informasi profil, (c) menghapus akun dan semua data terkait. '
                  'Hubungi kami di support@vibenime.app untuk request manual.',
            ),
            _Section(
              title: '7. Anak di Bawah Umur',
              body:
                  'VibeNime tidak ditujukan untuk pengguna di bawah 13 tahun. '
                  'Kami tidak sengaja mengumpulkan data anak. Jika Anda orang '
                  'tua dan menemukan data anak Anda di aplikasi, hubungi kami '
                  'untuk penghapusan.',
            ),
            _Section(
              title: '8. Perubahan Kebijakan',
              body:
                  'Kami dapat memperbarui kebijakan ini sewaktu-waktu. '
                  'Perubahan signifikan akan diberitahukan via notifikasi '
                  'aplikasi. Penggunaan berkelanjutan setelah update berarti '
                  'Anda menyetujui perubahan tersebut.',
            ),
            _Section(
              title: '9. Kontak',
              body:
                  'Pertanyaan tentang privasi? Email kami di:\n'
                  'support@vibenime.app',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.roboto(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
