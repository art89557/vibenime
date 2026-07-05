import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../auth/presentation/app_auth_controller.dart';
import '../../data/watch_party.dart';
import '../../data/watch_party_repository.dart';
import '../watch_party_providers.dart';
import '../../../../core/theme/app_radius.dart';

/// Card "Pesta Nonton" yang muncul di AnimeDetailScreen di atas list episode.
///
/// **State UI dinamis berdasarkan `activePartiesProvider`:**
///
/// | State                | UI yang ditampilkan                                 |
/// |----------------------|-----------------------------------------------------|
/// | Loading              | shimmer / placeholder pendek                        |
/// | Error                | hidden (silent fail — feature opsional)             |
/// | Empty (no parties)   | tombol "Mulai Pesta Nonton" (host)                  |
/// | 1+ active parties    | list mini "Gabung Pesta" — tap navigate ke /watch   |
///
/// **Auth flow:**
/// - Untuk **host**: butuh Supabase Auth (RLS check `auth.role()=authenticated`)
///   → kalau belum login Supabase, redirect ke `/admin/login`
/// - Untuk **viewer (join)**: tidak butuh auth (RLS allow read active party)
class StartPartyCard extends ConsumerWidget {
  const StartPartyCard({
    required this.animeId,
    required this.animeTitle,
    required this.episodeNumber,
    super.key,
  });

  /// AniList anime ID yang lagi dilihat user.
  final int animeId;

  /// Title anime — buat dipakai di snackbar feedback.
  final String animeTitle;

  /// Episode default kalau user mulai pesta baru (biasanya 1).
  final int episodeNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncParties = ref.watch(activePartiesProvider(animeId));

    return asyncParties.when(
      loading: () => const _CardShell(child: _LoadingState()),
      error: (_, _) => const SizedBox.shrink(),
      data: (parties) {
        if (parties.isEmpty) {
          return _CardShell(
            child: _StartHostBlock(
              animeId: animeId,
              animeTitle: animeTitle,
              episodeNumber: episodeNumber,
              onCreateRequested: () => _handleCreate(context, ref),
            ),
          );
        }
        return _CardShell(
          child: _JoinPartyBlock(
            parties: parties,
            onJoin: (party) => _handleJoin(context, party),
            onCreateAnother: () => _handleCreate(context, ref),
          ),
        );
      },
    );
  }

  // ─── Handlers ──────────────────────────────────────────────────────────

  /// Host flow: buat party baru di Supabase → navigate ke /watch-party/:id.
  ///
  /// Kalau belum login app (mode tamu) → arahkan ke login screen.
  Future<void> _handleCreate(BuildContext context, WidgetRef ref) async {
    Haptic.medium();
    final appUser = ref.read(appAuthControllerProvider).user;
    if (appUser == null) {
      AppSnackbar.info(context, context.l10n.wpLoginToStart);
      // ignore: use_build_context_synchronously
      context.push(AppRoutes.login);
      return;
    }

    try {
      final repo = ref.read(watchPartyRepositoryProvider);
      final party = await repo.createParty(
        animeId: animeId,
        episodeNumber: episodeNumber,
        hostUsername: appUser.username,
      );
      // Refresh list aktif parties supaya next visit langsung kelihatan
      // (tidak strictly needed karena navigate langsung, tapi untuk consistency).
      ref.invalidate(activePartiesProvider(animeId));

      if (!context.mounted) return;
      AppSnackbar.success(context, context.l10n.wpStarted);
      context.push(AppRoutes.watchPartyPath(party.id));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.error(context, context.l10n.wpStartFailed(e.toString()));
    }
  }

  /// Viewer flow: langsung navigate ke /watch-party/:id (no Supabase auth
  /// required untuk read; chat akan minta login kalau user mau ngetik).
  void _handleJoin(BuildContext context, WatchParty party) {
    Haptic.light();
    context.push(AppRoutes.watchPartyPath(party.id));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _CardShell — wrapper card consistent (border + padding + bg)
// ─────────────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.surfaceElevated(context),
          ],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _LoadingState — kompact untuk slot loading
// ─────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            context.l10n.wpChecking,
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _StartHostBlock — empty state, tombol "Mulai Pesta"
// ─────────────────────────────────────────────────────────────────────────

class _StartHostBlock extends StatelessWidget {
  const _StartHostBlock({
    required this.animeId,
    required this.animeTitle,
    required this.episodeNumber,
    required this.onCreateRequested,
  });

  final int animeId;
  final String animeTitle;
  final int episodeNumber;
  final VoidCallback onCreateRequested;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.groups_2_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.wpTitle,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.wpSubtitle,
                    style: GoogleFonts.roboto(
                      fontSize: 11.5,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreateRequested,
            icon: const Icon(Icons.live_tv_rounded, size: 18),
            label: Text(context.l10n.wpStartButton),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface(context),
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _JoinPartyBlock — show active parties list (max 3) + Join button
// ─────────────────────────────────────────────────────────────────────────

class _JoinPartyBlock extends StatelessWidget {
  const _JoinPartyBlock({
    required this.parties,
    required this.onJoin,
    required this.onCreateAnother,
  });

  final List<WatchParty> parties;
  final ValueChanged<WatchParty> onJoin;
  final VoidCallback onCreateAnother;

  @override
  Widget build(BuildContext context) {
    final visible = parties.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${parties.length} Pesta Nonton aktif',
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...visible.map((p) => _PartyTile(party: p, onTap: () => onJoin(p))),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onCreateAnother,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(context.l10n.wpStartOwn),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.zero,
            textStyle: GoogleFonts.roboto(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({required this.party, required this.onTap});

  final WatchParty party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                child: Text(
                  party.hostUsername.isNotEmpty
                      ? party.hostUsername.characters.first.toUpperCase()
                      : '?',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${party.hostUsername}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EP ${party.episodeNumber} · ${party.participantCount} nonton',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Gabung',
                  style: GoogleFonts.roboto(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surface(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
