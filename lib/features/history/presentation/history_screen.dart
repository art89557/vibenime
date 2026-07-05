import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/animation/animations.dart';
import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../anime_detail/presentation/anime_detail_providers.dart';
import '../data/history_entry.dart';
import 'history_item_menu.dart';
import 'history_providers.dart';
import '../../../core/theme/app_radius.dart';

// ── Warna timeline node (high-contrast, di luar palet cyan supaya menonjol) ──
/// Ungu — episode SELESAI ditonton (≥90% / sisa <30 dtk).
const _completedColor = Color(0xFF8B5CF6);

/// Amber — episode ditonton SEBAGIAN (masih ada sisa).
const _partialColor = AppColors.warning;

String _fmtDur(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Resume / replay → buka player di episode ybs (player handle posisi).
void _play(BuildContext context, int animeId, String episodeId) =>
    context.push(AppRoutes.playerPath(animeId.toString(), episodeId));

/// Layar Riwayat Menonton — dua mode layout yang bisa di-toggle:
///
/// - **Single View** (`_isDetailedView == false`): satu tile ringkas per anime,
///   menampilkan thumbnail + judul + episode terakhir + tombol play cepat.
/// - **Multi/Detailed View**: kartu per anime berisi header + timeline vertikal
///   semua episode yang ditonton (node ungu = selesai, amber = sebagian),
///   lengkap dengan progress bar tipis + tombol resume/replay per episode.
///
/// Hapus item tersedia via long-press (membuka [showWatchItemMenu]).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isDetailedView = false;

  void _toggleView() {
    Haptic.selection();
    setState(() => _isDetailedView = !_isDetailedView);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(allHistorySortedProvider);
    final groups = _groupByAnime(entries);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context, fallback: AppRoutes.home),
        ),
        title: Text(
          context.l10n.historyTitle,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: _isDetailedView
                  ? context.l10n.historyViewCompact
                  : context.l10n.historyViewDetailed,
              icon: Icon(
                _isDetailedView
                    ? Icons.view_list_rounded
                    : Icons.view_agenda_rounded,
                color: AppColors.primary,
              ),
              onPressed: _toggleView,
            ),
        ],
      ),
      body: entries.isEmpty
          ? _empty(context)
          : AnimatedSwitcher(
              duration: AppAnimations.reduceMotion(context)
                  ? Duration.zero
                  : AppAnimations.short,
              child: _isDetailedView
                  ? _DetailedList(
                      key: const ValueKey('detailed'),
                      groups: groups,
                    )
                  : _CompactList(
                      key: const ValueKey('compact'),
                      groups: groups,
                    ),
            ),
    );
  }

  /// Group entry per anime, mempertahankan urutan recency (entry sudah urut
  /// terbaru → anime yang baru ditonton muncul di atas). Episode di tiap grup
  /// tetap urut terbaru-dulu di sini; view detail yang menyusun kronologis.
  List<_AnimeGroup> _groupByAnime(List<HistoryEntry> entries) {
    final map = <int, List<HistoryEntry>>{};
    for (final e in entries) {
      map.putIfAbsent(e.animeId, () => []).add(e);
    }
    return [
      for (final entry in map.entries)
        _AnimeGroup(animeId: entry.key, episodes: entry.value),
    ];
  }

  Widget _empty(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.history_rounded,
          size: 56,
          color: AppColors.textMuted(context),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.historyEmpty,
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    ),
  );
}

/// Satu anime + semua episode-nya dalam riwayat (urut terbaru-dulu).
class _AnimeGroup {
  const _AnimeGroup({required this.animeId, required this.episodes});

  final int animeId;
  final List<HistoryEntry> episodes;

  /// Episode paling terakhir ditonton (untuk tile ringkas + quick resume).
  HistoryEntry get latest => episodes.first;
}

// ─────────────────────────── SINGLE / COMPACT VIEW ──────────────────────────

class _CompactList extends StatelessWidget {
  const _CompactList({required this.groups, super.key});

  final List<_AnimeGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: groups.length,
      itemBuilder: (_, i) => _CompactAnimeTile(group: groups[i]),
    );
  }
}

class _CompactAnimeTile extends ConsumerWidget {
  const _CompactAnimeTile({required this.group});

  final _AnimeGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = group.latest;
    final asyncAnime = ref.watch(animeDetailProvider(group.animeId));
    final cover = asyncAnime.valueOrNull?.coverImage ?? '';
    final title = asyncAnime.valueOrNull?.displayTitle ?? 'Memuat…';
    final frac = entry.progressFraction;

    return InkWell(
      onTap: () => _play(context, entry.animeId, entry.episodeId),
      onLongPress: () => showWatchItemMenu(context, ref, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 42,
                height: 56,
                child: cover.isEmpty
                    ? Container(color: AppColors.surfaceElevated(context))
                    : CachedNetworkImage(
                        imageUrl: cover,
                        memCacheWidth: 300,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.isFinished
                        ? 'Episode ${entry.episodeNumber} · selesai'
                        : 'Episode ${entry.episodeNumber} · ${_fmtDur(entry.position)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  if (frac != null && !entry.isFinished) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.tiny),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 3,
                        backgroundColor: AppColors.borderColor(context),
                        valueColor: const AlwaysStoppedAnimation(_partialColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PlayActionButton(
              finished: entry.isFinished,
              color: AppColors.primary,
              onTap: () => _play(context, entry.animeId, entry.episodeId),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── MULTI / DETAILED VIEW ──────────────────────────

class _DetailedList extends StatelessWidget {
  const _DetailedList({required this.groups, super.key});

  final List<_AnimeGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: groups.length,
      itemBuilder: (_, i) => _AnimeHistoryCard(group: groups[i]),
    );
  }
}

class _AnimeHistoryCard extends ConsumerWidget {
  const _AnimeHistoryCard({required this.group});

  final _AnimeGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAnime = ref.watch(animeDetailProvider(group.animeId));
    final cover = asyncAnime.valueOrNull?.coverImage ?? '';
    final title = asyncAnime.valueOrNull?.displayTitle ?? 'Memuat…';

    // Timeline kronologis: episode terkecil → terbesar (urutan tonton natural).
    final episodes = [...group.episodes]
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header anime ──
          InkWell(
            onTap: () => context.push(
              AppRoutes.animeDetailPath(group.animeId.toString()),
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 46,
                    height: 62,
                    child: cover.isEmpty
                        ? Container(color: AppColors.surfaceHigh(context))
                        : CachedNetworkImage(
                            memCacheWidth: 300,
                            imageUrl: cover,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${episodes.length} episode ditonton',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Timeline episode ──
          for (int i = 0; i < episodes.length; i++)
            _TimelineEpisodeNode(
              entry: episodes[i],
              isFirst: i == 0,
              isLast: i == episodes.length - 1,
            ),
        ],
      ),
    );
  }
}

/// Satu node pada timeline vertikal: gutter (dot + connector) + konten episode.
class _TimelineEpisodeNode extends ConsumerWidget {
  const _TimelineEpisodeNode({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final HistoryEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finished = entry.isFinished;
    final statusColor = finished ? _completedColor : _partialColor;
    final frac = entry.progressFraction;
    final lineColor = AppColors.borderColor(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Gutter: connector atas + dot + connector bawah ──
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 5,
                  color: isFirst ? Colors.transparent : lineColor,
                ),
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surfaceElevated(context),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.45),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Konten episode ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: InkWell(
                onLongPress: () => showWatchItemMenu(context, ref, entry),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Episode ${entry.episodeNumber}',
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (finished)
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: _completedColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Selesai ditonton',
                                  style: GoogleFonts.roboto(
                                    fontSize: 11,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'Left off at ${_fmtDur(entry.position)}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                          // Progress bar tipis hanya saat belum selesai.
                          if (!finished && frac != null) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.tiny,
                              ),
                              child: LinearProgressIndicator(
                                value: frac,
                                minHeight: 3,
                                backgroundColor: lineColor,
                                valueColor: const AlwaysStoppedAnimation(
                                  _partialColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _PlayActionButton(
                      finished: finished,
                      color: statusColor,
                      onTap: () =>
                          _play(context, entry.animeId, entry.episodeId),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol aksi kontekstual bulat: ▶ resume (belum selesai) / ⟲ replay (selesai).
class _PlayActionButton extends StatelessWidget {
  const _PlayActionButton({
    required this.finished,
    required this.color,
    required this.onTap,
  });

  final bool finished;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptic.light();
          onTap();
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Icon(
            finished ? Icons.replay_rounded : Icons.play_arrow_rounded,
            size: 19,
            color: color,
          ),
        ),
      ),
    );
  }
}
