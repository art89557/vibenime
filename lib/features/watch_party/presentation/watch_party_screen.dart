import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../shared/models/stream_source.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../anime_detail/presentation/anime_detail_providers.dart';
import '../../player/presentation/player_providers.dart';
import '../../auth/presentation/app_auth_controller.dart';
import '../data/watch_party.dart';
import '../data/watch_party_presence.dart';
import '../data/watch_party_repository.dart';
import 'chat_overlay.dart';
import 'watch_party_providers.dart';
import '../../../core/theme/app_radius.dart';

/// Layar **Watch Party** — nonton bareng real-time dengan sync playback +
/// chat overlay.
///
/// **Architecture:**
///
/// ```
/// ┌─ Header (host name, viewer count, host badge / "Akhiri") ─┐
/// │ ─────────────────────────────────────────────────────── │
/// │ [Video Player 16:9 — YouTube embed]                     │
/// │ ─────────────────────────────────────────────────────── │
/// │ [Chat overlay — list message + input field]             │
/// └──────────────────────────────────────────────────────────┘
/// ```
///
/// **Sync logic:**
/// - **Host**:
///   - Timer.periodic 2 detik → broadcast position + isPlaying via
///     `repo.updatePlayback`
///   - Bisa play/pause/seek bebas
/// - **Viewer**:
///   - Listen [partyStreamProvider] → on each emission, kalau diff > 3 detik
///     auto-seek; kalau isPlaying berubah, follow.
///   - Player controls disabled (no scrub bar interaction).
///
/// **Lifecycle**:
/// - Host close screen → call [WatchPartyRepository.endParty] → set
///   `is_active=false` → viewer akan disconnect via stream completion.
/// - Viewer close screen → just dispose; party tetap jalan untuk yang lain.
class WatchPartyScreen extends ConsumerStatefulWidget {
  const WatchPartyScreen({required this.partyId, super.key});

  final String partyId;

  @override
  ConsumerState<WatchPartyScreen> createState() => _WatchPartyScreenState();
}

class _WatchPartyScreenState extends ConsumerState<WatchPartyScreen> {
  /// Tolerance sync: kalau diff posisi > ini → auto-seek.
  static const _syncToleranceSeconds = 3;

  /// Interval host broadcast playback ke Supabase.
  static const _broadcastInterval = Duration(seconds: 2);

  /// Presence wrapper — track viewer di Realtime channel.
  WatchPartyPresence? _presence;

  /// Stream count viewer dari presence — di-update auto saat ada join/leave.
  Stream<int>? _presenceCountStream;

  @override
  void initState() {
    super.initState();
    // Defer init karena kita perlu user info yang baru tersedia setelah
    // widget mount.
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinPresence());
  }

  void _joinPresence() {
    final appUser = ref.read(appAuthControllerProvider).user;
    // Identity: Supabase user.id (primary). Fallback ephemeral kalau guest mode.
    final viewerId =
        appUser?.id ?? 'anon-${DateTime.now().microsecondsSinceEpoch}';
    final username = appUser?.username ?? 'Anon';

    _presence = ref.read(watchPartyPresenceProvider);
    final stream = _presence!.join(
      partyId: widget.partyId,
      viewerId: viewerId,
      username: username,
    );
    if (mounted) {
      setState(() => _presenceCountStream = stream);
    }
  }

  @override
  void dispose() {
    _presence?.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncParty = ref.watch(partyStreamProvider(widget.partyId));

    return Scaffold(
      backgroundColor: AppColors.surface(context),
      body: SafeArea(
        child: asyncParty.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorRetry(
              message: '${context.l10n.wpPartyUnavailable}: $e',
              onRetry: () =>
                  ref.invalidate(partyStreamProvider(widget.partyId)),
            ),
          ),
          data: (party) => _buildBody(context, party),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WatchParty party) {
    if (!party.isActive) {
      return _PartyEndedView(onBack: () => context.pop());
    }

    final selfId = Supabase.instance.client.auth.currentUser?.id;
    final isHost = selfId != null && selfId == party.hostUserId;

    return Column(
      children: [
        _PartyHeader(
          party: party,
          isHost: isHost,
          presenceCountStream: _presenceCountStream,
          onClose: () => _handleClose(context, party, isHost),
        ),
        Expanded(
          child: _PartyPlayerSection(party: party, isHost: isHost),
        ),
      ],
    );
  }

  /// Handler tombol close di header.
  /// - Host → confirm dialog → endParty + pop
  /// - Viewer → langsung pop (party tetap jalan untuk yang lain)
  Future<void> _handleClose(
    BuildContext context,
    WatchParty party,
    bool isHost,
  ) async {
    Haptic.light();
    if (!isHost) {
      context.pop();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated(context),
        title: Text(
          context.l10n.wpEndConfirmTitle,
          style: GoogleFonts.roboto(
            color: AppColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          context.l10n.wpEndConfirmBody,
          style: GoogleFonts.roboto(
            color: AppColors.textMuted(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              context.l10n.actionCancel,
              style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.l10n.wpEnd),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(watchPartyRepositoryProvider).endParty(party.id);
        // Refresh activePartiesProvider supaya Detail screen sync (card
        // "Pesta Nonton aktif" hilang saat host kembali ke detail).
        ref.invalidate(activePartiesProvider(party.animeId));
        if (!context.mounted) return;
        AppSnackbar.success(context, context.l10n.wpEnded);
        // Eksplisit navigate ke Detail anime — bukan pop, supaya tidak
        // "nyangkut" di route /watch-party walaupun stream masih aktif.
        context.go(AppRoutes.animeDetailPath(party.animeId.toString()));
      } catch (e) {
        if (!context.mounted) return;
        AppSnackbar.error(context, '${context.l10n.wpEndFailed}: $e');
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _PartyHeader — top bar dengan host name + viewer count + close
// ─────────────────────────────────────────────────────────────────────────

class _PartyHeader extends StatelessWidget {
  const _PartyHeader({
    required this.party,
    required this.isHost,
    required this.onClose,
    this.presenceCountStream,
  });

  final WatchParty party;
  final bool isHost;
  final VoidCallback onClose;

  /// Stream count viewer dari Supabase Realtime Presence — null saat
  /// belum subscribe (initial state).
  final Stream<int>? presenceCountStream;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor(context)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(
              isHost
                  ? Icons.power_settings_new_rounded
                  : Icons.arrow_back_rounded,
              color: isHost ? AppColors.error : AppColors.textPrimary(context),
            ),
            tooltip: isHost ? context.l10n.wpEndTooltip : context.l10n.wpLeave,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isHost
                            ? context.l10n.wpYouAreHost
                            : context.l10n.wpHostedBy(party.hostUsername),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isHost
                              ? AppColors.primary
                              : AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // **Realtime presence count** — fallback ke
                // `party.participantCount` kalau stream belum subscribe.
                StreamBuilder<int>(
                  stream: presenceCountStream,
                  initialData: party.participantCount,
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? party.participantCount;
                    return Text(
                      context.l10n.wpEpViewers(party.episodeNumber, count),
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (isHost)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'HOST',
                style: GoogleFonts.roboto(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _PartyPlayerSection — player + chat overlay
// ─────────────────────────────────────────────────────────────────────────

class _PartyPlayerSection extends ConsumerWidget {
  const _PartyPlayerSection({required this.party, required this.isHost});

  final WatchParty party;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cari episode ID dari party.animeId + party.episodeNumber.
    final asyncEps = ref.watch(animeEpisodesProvider(party.animeId));

    return asyncEps.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, _) => Center(
        child: Text(
          context.l10n.wpEpisodeNotFound,
          style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
        ),
      ),
      data: (eps) {
        final episode = eps.firstWhere(
          (e) => e.number == party.episodeNumber,
          orElse: () => eps.first,
        );

        final args = (animeId: party.animeId, episodeId: episode.id);
        final asyncPayloads = ref.watch(streamPayloadsProvider(args));

        return asyncPayloads.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Text(
              '${context.l10n.errorGeneric}: $e',
              style: GoogleFonts.roboto(color: AppColors.error, fontSize: 12),
            ),
          ),
          data: (payloads) {
            if (payloads.isEmpty) {
              return Center(
                child: Text(
                  context.l10n.wpNoSource,
                  style: TextStyle(color: AppColors.textMuted(context)),
                ),
              );
            }
            // Pakai payload pertama saja untuk simplicity (party host pilih
            // source default — viewer harus follow source yang sama).
            final payload = payloads.first;

            return Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: payload.isYoutube
                        ? _SyncedYoutubePlayer(
                            videoId: payload.youtubeVideoId!,
                            party: party,
                            isHost: isHost,
                          )
                        : _UnsupportedSourceNotice(payload: payload),
                  ),
                ),
                Expanded(child: ChatOverlay(partyId: party.id)),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _SyncedYoutubePlayer — YouTube player dengan sync logic host/viewer
// ─────────────────────────────────────────────────────────────────────────

class _SyncedYoutubePlayer extends ConsumerStatefulWidget {
  const _SyncedYoutubePlayer({
    required this.videoId,
    required this.party,
    required this.isHost,
  });

  final String videoId;
  final WatchParty party;
  final bool isHost;

  @override
  ConsumerState<_SyncedYoutubePlayer> createState() =>
      _SyncedYoutubePlayerState();
}

class _SyncedYoutubePlayerState extends ConsumerState<_SyncedYoutubePlayer> {
  late final YoutubePlayerController _controller;
  Timer? _broadcastTimer;
  ProviderSubscription<AsyncValue<WatchParty>>? _partySub;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        startAt: widget.party.currentPositionSeconds,
        // Host bisa pakai full controls; viewer hide controls untuk avoid
        // confusing interaction (sync logic akan override).
        hideControls: !widget.isHost,
      ),
    );

    if (widget.isHost) {
      _startHostBroadcast();
    } else {
      _startViewerSync();
    }
  }

  /// Host: broadcast posisi tiap 2 detik ke Supabase.
  void _startHostBroadcast() {
    _broadcastTimer = Timer.periodic(
      _WatchPartyScreenState._broadcastInterval,
      (_) async {
        if (!_controller.value.isReady) return;
        final pos = _controller.value.position.inSeconds;
        final playing = _controller.value.isPlaying;
        try {
          await ref
              .read(watchPartyRepositoryProvider)
              .updatePlayback(
                partyId: widget.party.id,
                positionSeconds: pos,
                isPlaying: playing,
              );
        } catch (_) {
          // Silent — next tick akan retry.
        }
      },
    );
  }

  /// Viewer: subscribe ke partyStreamProvider; setiap update cek diff posisi.
  void _startViewerSync() {
    _partySub = ref.listenManual<AsyncValue<WatchParty>>(
      partyStreamProvider(widget.party.id),
      (prev, next) {
        next.whenData(_applyHostState);
      },
      fireImmediately: false,
    );
  }

  /// Apply state host ke local player kalau ada divergence.
  void _applyHostState(WatchParty hostState) {
    if (!_controller.value.isReady) return;
    final localPos = _controller.value.position.inSeconds;
    final hostPos = hostState.currentPositionSeconds;
    final diff = (localPos - hostPos).abs();

    // 1. Sync posisi kalau drift > tolerance
    if (diff > _WatchPartyScreenState._syncToleranceSeconds) {
      _controller.seekTo(Duration(seconds: hostPos));
    }
    // 2. Sync play/pause
    if (hostState.isPlaying && !_controller.value.isPlaying) {
      _controller.play();
    } else if (!hostState.isPlaying && _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    _partySub?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: widget.isHost,
          progressIndicatorColor: AppColors.primary,
          progressColors: const ProgressBarColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.secondary,
          ),
        ),
        // Viewer overlay: hint kalau player di-control oleh host
        if (!widget.isHost)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sync_rounded,
                    size: 11,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.wpSyncToHost,
                    style: GoogleFonts.roboto(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _UnsupportedSourceNotice — fallback kalau source bukan YouTube
// (sync logic untuk HLS belum diimplement di MVP)
// ─────────────────────────────────────────────────────────────────────────

class _UnsupportedSourceNotice extends StatelessWidget {
  const _UnsupportedSourceNotice({required this.payload});
  final StreamPayload payload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.warning,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.wpYoutubeOnly,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _PartyEndedView — empty state kalau party.is_active=false
// ─────────────────────────────────────────────────────────────────────────

class _PartyEndedView extends StatelessWidget {
  const _PartyEndedView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              color: AppColors.textMuted(context),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.wpEndedTitle,
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.wpEndedBody,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBack,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface(context),
              ),
              child: Text(context.l10n.actionBack),
            ),
          ],
        ),
      ),
    );
  }
}
