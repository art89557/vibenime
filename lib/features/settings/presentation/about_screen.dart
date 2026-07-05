import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/theme/app_radius.dart';

/// About / Credits screen — info aplikasi untuk laporan + presentasi tugas.
///
/// Section:
/// - Header: logo + nama + versi + tagline
/// - Tech Stack: list teknologi yang dipakai
/// - Fitur Utama: highlight 10 fitur
/// - Credits: developer + supervisor
/// - Links: GitHub + AniList + dokumentasi
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const _version = '1.0.0';

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              NavHelper.safePop(context, fallback: AppRoutes.settings),
        ),
        title: Text(
          context.l10n.settingsAbout,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _Header(),
            const SizedBox(height: 28),
            _SectionTitle('Tech Stack'),
            const SizedBox(height: 10),
            _TechGrid(),
            const SizedBox(height: 24),
            _SectionTitle('Fitur Utama'),
            const SizedBox(height: 10),
            _FeatureList(),
            const SizedBox(height: 24),
            _SectionTitle('Credits'),
            const SizedBox(height: 10),
            _CreditCard(),
            const SizedBox(height: 24),
            _SectionTitle('Tautan'),
            const SizedBox(height: 10),
            _LinkButton(
              icon: Icons.code_rounded,
              label: 'GitHub Repository',
              url: 'https://github.com/yourusername/vibenime',
              onTap: _openUrl,
            ),
            const SizedBox(height: 8),
            _LinkButton(
              icon: Icons.library_books_rounded,
              label: 'AniList — sumber metadata',
              url: 'https://anilist.co',
              onTap: _openUrl,
            ),
            const SizedBox(height: 8),
            _LinkButton(
              icon: Icons.storage_rounded,
              label: 'Supabase — backend',
              url: 'https://supabase.com',
              onTap: _openUrl,
            ),
            const SizedBox(height: 32),
            _Footer(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _Header — logo + nama + versi
// ─────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 52,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'VibeNime',
          style: GoogleFonts.playfairDisplay(
            fontSize: 36,
            fontStyle: FontStyle.italic,
            color: AppColors.textPrimary(context),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vibe-mu, anime-mu.',
          style: GoogleFonts.roboto(
            fontSize: 13,
            letterSpacing: 1,
            color: AppColors.textMuted(context),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Text(
            'v${AboutScreen._version}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _SectionTitle — header section dengan icon mono
// ─────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _TechGrid — 2-column grid tech stack
// ─────────────────────────────────────────────────────────────────────────

class _TechGrid extends StatelessWidget {
  static const _items = [
    ('Flutter 3.x', Icons.flutter_dash_rounded),
    ('Riverpod', Icons.account_tree_rounded),
    ('Supabase', Icons.storage_rounded),
    ('AniList GraphQL', Icons.api_rounded),
    ('better_player_plus', Icons.play_circle_rounded),
    ('youtube_player_flutter', Icons.smart_display_rounded),
    ('Hive (offline)', Icons.save_rounded),
    ('go_router', Icons.alt_route_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.5,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Row(
            children: [
              Icon(item.$2, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _FeatureList — 10 fitur utama dengan icon
// ─────────────────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  static const _features = [
    ('Streaming + Multi-source fallback', Icons.layers_rounded),
    ('Watch Party real-time dengan chat', Icons.groups_rounded),
    ('Download offline (Internet Archive)', Icons.download_rounded),
    ('Diskusi per anime + emoji gift', Icons.forum_rounded),
    ('Auth Supabase (register/login)', Icons.lock_rounded),
    ('AniList sync My List (optional)', Icons.sync_rounded),
    ('Filter Search: genre/tahun/musim/format', Icons.tune_rounded),
    ('Episode picker + history persist', Icons.history_rounded),
    ('Admin panel dengan bulk insert', Icons.admin_panel_settings_rounded),
    ('Light/Dark mode + persistence', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _features.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      _features[i].$2,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _features[i].$1,
                      style: GoogleFonts.roboto(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != _features.length - 1)
              Divider(height: 1, color: AppColors.borderColor(context)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _CreditCard — developer info
// ─────────────────────────────────────────────────────────────────────────

class _CreditCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.surfaceElevated(context),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Tugas Kuliah',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pengembangan Aplikasi Mobile',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Dibuat sebagai final project dengan Flutter, '
            'mengintegrasikan AniList GraphQL + Supabase real-time backend.',
            style: GoogleFonts.roboto(
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _LinkButton — tombol link external dengan icon
// ─────────────────────────────────────────────────────────────────────────

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String url;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Haptic.light();
        onTap(url);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: AppColors.textMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            '— Made with Flutter 💙 —',
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2026 VibeNime',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
