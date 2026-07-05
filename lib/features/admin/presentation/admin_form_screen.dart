import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/constants.dart';
import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/source_type.dart';
import '../../../core/utils/youtube_url.dart';
import '../../../shared/models/anime.dart';
import '../../discover/data/anime_repository.dart';
import '../../player/data/video_catalog_repository.dart';
import 'admin_providers.dart';
import '../../../core/theme/app_radius.dart';

/// Form add/edit video source — polished sectioned layout.
///
/// Sections:
/// 1. **Anime** — AniList ID + auto-preview judul anime
/// 2. **Source** — video URL + subtitle URL + visual source type picker
/// 3. **Metadata** — episode number, quality chips, language, priority slider
/// 4. **Notes** — free-text notes
///
/// Sticky bottom action bar dengan Save (+ Delete kalau edit mode).
class AdminFormScreen extends ConsumerStatefulWidget {
  const AdminFormScreen({this.existing, super.key});

  final VideoSource? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<AdminFormScreen> createState() => _AdminFormScreenState();
}

class _AdminFormScreenState extends ConsumerState<AdminFormScreen> {
  late final TextEditingController _anilistIdCtrl;
  late final TextEditingController _episodeCtrl;
  late final TextEditingController _videoUrlCtrl;
  late final TextEditingController _subtitleUrlCtrl;
  late final TextEditingController _languageCtrl;
  late final TextEditingController _notesCtrl;
  String _quality = '480p';
  SourceType _sourceType = SourceType.archiveOrg;
  int _priority = PaginationConstants.defaultSourcePriority;
  bool _saving = false;

  // URL validation state
  bool? _videoUrlValid;

  // Anime title preview state
  Anime? _resolvedAnime;
  bool _resolvingAnime = false;
  Timer? _anilistIdDebounce;

  static const _qualities = ['240p', '360p', '480p', '720p', '1080p', 'auto'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _anilistIdCtrl = TextEditingController(text: e?.anilistId.toString() ?? '');
    _episodeCtrl = TextEditingController(
      text: e?.episodeNumber.toString() ?? '1',
    );
    _videoUrlCtrl = TextEditingController(text: e?.videoUrl ?? '');
    _subtitleUrlCtrl = TextEditingController(text: e?.subtitleUrl ?? '');
    _languageCtrl = TextEditingController(text: e?.language ?? 'en');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _quality = e?.quality ?? '480p';
    _sourceType = e?.sourceTypeEnum ?? SourceType.archiveOrg;
    _priority = e?.priority ?? PaginationConstants.defaultSourcePriority;

    _videoUrlCtrl.addListener(_onVideoUrlChanged);
    _anilistIdCtrl.addListener(_onAnilistIdChanged);

    if (widget.isEdit) {
      _onVideoUrlChanged();
      _onAnilistIdChanged();
    }
  }

  void _onVideoUrlChanged() {
    final raw = _videoUrlCtrl.text.trim();
    setState(() {
      if (raw.isEmpty) {
        _videoUrlValid = null;
        return;
      }
      if (_sourceType == SourceType.youtube) {
        _videoUrlValid = extractYoutubeId(raw) != null;
      } else {
        _videoUrlValid =
            raw.startsWith('http://') || raw.startsWith('https://');
      }
    });
  }

  void _onAnilistIdChanged() {
    _anilistIdDebounce?.cancel();
    _anilistIdDebounce = Timer(const Duration(milliseconds: 800), () async {
      final id = int.tryParse(_anilistIdCtrl.text.trim());
      if (id == null || id <= 0) {
        if (mounted) setState(() => _resolvedAnime = null);
        return;
      }
      if (mounted) setState(() => _resolvingAnime = true);
      try {
        final anime = await ref.read(animeRepositoryProvider).getDetail(id);
        if (mounted) setState(() => _resolvedAnime = anime);
      } catch (_) {
        if (mounted) setState(() => _resolvedAnime = null);
      } finally {
        if (mounted) setState(() => _resolvingAnime = false);
      }
    });
  }

  @override
  void dispose() {
    _videoUrlCtrl.removeListener(_onVideoUrlChanged);
    _anilistIdCtrl.removeListener(_onAnilistIdChanged);
    _anilistIdDebounce?.cancel();
    _anilistIdCtrl.dispose();
    _episodeCtrl.dispose();
    _videoUrlCtrl.dispose();
    _subtitleUrlCtrl.dispose();
    _languageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final anilistId = int.tryParse(_anilistIdCtrl.text.trim());
    final episode = int.tryParse(_episodeCtrl.text.trim());
    final videoUrl = _videoUrlCtrl.text.trim();

    if (anilistId == null || anilistId <= 0) {
      _showError(context.l10n.adminValIdPositive);
      return;
    }
    if (episode == null || episode <= 0) {
      _showError(context.l10n.adminValEpPositive);
      return;
    }
    if (videoUrl.isEmpty || Uri.tryParse(videoUrl)?.hasScheme != true) {
      _showError(context.l10n.adminValUrl);
      return;
    }

    Haptic.medium();
    setState(() => _saving = true);
    try {
      final repo = ref.read(videoCatalogRepositoryProvider);
      if (widget.isEdit) {
        await repo.update(
          widget.existing!.copyWith(
            anilistId: anilistId,
            episodeNumber: episode,
            videoUrl: videoUrl,
            subtitleUrl: _subtitleUrlCtrl.text.trim().isEmpty
                ? null
                : _subtitleUrlCtrl.text.trim(),
            language: _languageCtrl.text.trim(),
            quality: _quality,
            sourceType: _sourceType.value,
            priority: _priority,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          ),
        );
      } else {
        await repo.insert(
          anilistId: anilistId,
          episodeNumber: episode,
          videoUrl: videoUrl,
          subtitleUrl: _subtitleUrlCtrl.text.trim().isEmpty
              ? null
              : _subtitleUrlCtrl.text.trim(),
          language: _languageCtrl.text.trim(),
          quality: _quality,
          sourceType: _sourceType.value,
          priority: _priority,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      ref.invalidate(adminVideoSourcesProvider);
      if (!mounted) return;
      AppSnackbar.success(
        context,
        widget.isEdit ? context.l10n.adminSaved : context.l10n.adminAdded,
      );
      context.pop();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!widget.isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated(context),
        title: Text(
          context.l10n.adminDeleteVideoQ,
          style: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          context.l10n.adminDeleteVideoBody,
          style: GoogleFonts.roboto(
            fontSize: 13,
            color: AppColors.textMuted(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.l10n.commonCancel,
              style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    Haptic.heavy();
    setState(() => _saving = true);
    final deleted = widget.existing!;
    try {
      await ref.read(videoCatalogRepositoryProvider).delete(deleted.id);
      ref.invalidate(adminVideoSourcesProvider);
      if (!mounted) return;

      AppSnackbar.undoable(
        context,
        message: context.l10n.adminVideoDeleted,
        onUndo: () async {
          try {
            await ref
                .read(videoCatalogRepositoryProvider)
                .insert(
                  anilistId: deleted.anilistId,
                  episodeNumber: deleted.episodeNumber,
                  videoUrl: deleted.videoUrl,
                  subtitleUrl: deleted.subtitleUrl,
                  language: deleted.language,
                  quality: deleted.quality,
                  sourceType: deleted.sourceType,
                  priority: deleted.priority,
                  notes: deleted.notes,
                );
            ref.invalidate(adminVideoSourcesProvider);
          } catch (_) {
            /* best-effort */
          }
        },
      );
      context.pop();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) => AppSnackbar.error(context, msg);

  Future<void> _openAniList() async {
    final id = int.tryParse(_anilistIdCtrl.text.trim());
    if (id == null) {
      _showError(context.l10n.adminEnterIdFirst);
      return;
    }
    final url = Uri.parse('https://anilist.co/anime/$id');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showError(context.l10n.adminOpenLinkFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              NavHelper.safePop(context, fallback: AppRoutes.adminPanel),
        ),
        title: Text(
          widget.isEdit ? 'Edit Video' : context.l10n.adminAddVideo,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _SectionCard(
                title: 'Anime',
                icon: Icons.movie_rounded,
                child: _animeSection(),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Source',
                icon: Icons.video_settings_rounded,
                child: _sourceSection(),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Metadata',
                icon: Icons.tune_rounded,
                child: _metadataSection(),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Notes',
                icon: Icons.notes_rounded,
                child: TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Astro Boy 1963 — Episode 1',
                  ),
                ),
              ),
              if (widget.isEdit) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(context.l10n.adminDeleteThisVideo),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ],
          ),

          // Sticky bottom save bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                10 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(context),
                border: Border(
                  top: BorderSide(color: AppColors.borderColor(context)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onAccent,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onAccent,
                          ),
                        )
                      : Icon(
                          widget.isEdit
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                        ),
                  label: Text(
                    widget.isEdit
                        ? context.l10n.adminSaveChanges
                        : context.l10n.adminAddToCatalog,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section: Anime ────────────────────────────────────────────────────

  Widget _animeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('AniList ID'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _anilistIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: context.l10n.adminIdHint),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openAniList,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(context.l10n.adminCheck),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
        _AnimePreviewBadge(anime: _resolvedAnime, isLoading: _resolvingAnime),
      ],
    );
  }

  // ─── Section: Source ───────────────────────────────────────────────────

  Widget _sourceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Source Type'),
        _SourceTypeChips(
          selected: _sourceType,
          onSelected: (t) {
            setState(() => _sourceType = t);
            _onVideoUrlChanged();
          },
        ),
        const SizedBox(height: 14),
        const _Label('Video URL'),
        TextField(
          controller: _videoUrlCtrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          maxLines: 2,
          minLines: 1,
          style: GoogleFonts.jetBrainsMono(fontSize: 12),
          decoration: InputDecoration(
            hintText: _sourceType.placeholder,
            suffixIcon: _videoUrlValid == null
                ? null
                : Icon(
                    _videoUrlValid!
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: _videoUrlValid!
                        ? AppColors.success
                        : AppColors.warning,
                    size: 18,
                  ),
          ),
        ),
        if (_sourceType == SourceType.youtube) ...[
          const SizedBox(height: 6),
          _ExternalLinkRow(),
        ],
        const SizedBox(height: 14),
        _Label(context.l10n.adminSubtitleOptional),
        TextField(
          controller: _subtitleUrlCtrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: GoogleFonts.jetBrainsMono(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'https://...captions.vtt',
          ),
        ),
      ],
    );
  }

  // ─── Section: Metadata ─────────────────────────────────────────────────

  Widget _metadataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Episode'),
                  TextField(
                    controller: _episodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '1'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Language'),
                  TextField(
                    controller: _languageCtrl,
                    decoration: const InputDecoration(hintText: 'en'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _Label('Quality'),
        _QualityChips(
          selected: _quality,
          onSelected: (q) => setState(() => _quality = q),
          qualities: _qualities,
        ),
        const SizedBox(height: 14),
        _Label('Priority — $_priority'),
        _PrioritySlider(
          value: _priority,
          onChanged: (v) => setState(() => _priority = v),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _SectionCard — wrapper konsisten untuk tiap section
// ─────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _SourceTypeChips — visual picker dengan icon
// ─────────────────────────────────────────────────────────────────────────

class _SourceTypeChips extends StatelessWidget {
  const _SourceTypeChips({required this.selected, required this.onSelected});

  final SourceType selected;
  final ValueChanged<SourceType> onSelected;

  static IconData _iconFor(SourceType t) {
    switch (t) {
      case SourceType.archiveOrg:
        return Icons.public_rounded;
      case SourceType.youtube:
        return Icons.play_circle_filled_rounded;
      case SourceType.mux:
        return Icons.stream_rounded;
      case SourceType.cloudflareR2:
        return Icons.cloud_rounded;
      case SourceType.manual:
        return Icons.link_rounded;
    }
  }

  static Color _colorFor(SourceType t) {
    switch (t) {
      case SourceType.archiveOrg:
        return AppColors.success;
      case SourceType.youtube:
        return AppColors.error;
      case SourceType.mux:
        return AppColors.warning;
      case SourceType.cloudflareR2:
        return AppColors.primary;
      case SourceType.manual:
        return AppColors.textOnDarkMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SourceType.values.map((t) {
        final isActive = t == selected;
        final color = _colorFor(t);
        return GestureDetector(
          onTap: () {
            Haptic.selection();
            onSelected(t);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.18)
                  : AppColors.surface(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isActive ? color : AppColors.borderColor(context),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconFor(t),
                  size: 14,
                  color: isActive ? color : AppColors.textMuted(context),
                ),
                const SizedBox(width: 6),
                Text(
                  t.label,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? color : AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _QualityChips — pill chips compact
// ─────────────────────────────────────────────────────────────────────────

class _QualityChips extends StatelessWidget {
  const _QualityChips({
    required this.selected,
    required this.onSelected,
    required this.qualities,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final List<String> qualities;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: qualities.map((q) {
        final isActive = q == selected;
        return GestureDetector(
          onTap: () {
            Haptic.selection();
            onSelected(q);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.surface(context),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isActive
                    ? AppColors.primary
                    : AppColors.borderColor(context),
              ),
            ),
            child: Text(
              q,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppColors.onAccent
                    : AppColors.textPrimary(context),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _PrioritySlider — slider 1-200 dengan color preview
// ─────────────────────────────────────────────────────────────────────────

class _PrioritySlider extends StatelessWidget {
  const _PrioritySlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  /// Color-coded priority sama dengan badge di card admin list.
  static Color _colorFor(int p) {
    if (p <= 50) return AppColors.success;
    if (p <= 100) return AppColors.primary;
    if (p <= 150) return AppColors.warning;
    return AppColors.textOnDarkMuted;
  }

  static String _hintFor(BuildContext context, int p) {
    if (p <= 50) return context.l10n.adminPriorityPrimary;
    if (p <= 100) return context.l10n.adminPriorityDefault;
    if (p <= 150) return context.l10n.adminPriorityBackup;
    return context.l10n.adminPriorityLast;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.tiny),
                border: Border.all(color: color),
              ),
              child: Text(
                'P$value',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _hintFor(context, value),
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: AppColors.textMuted(context),
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: AppColors.borderColor(context),
            overlayColor: color.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 200,
            divisions: 199,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppColors.textMuted(context),
                ),
              ),
              Text(
                context.l10n.adminPrioritySmaller,
                style: GoogleFonts.roboto(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted(context),
                ),
              ),
              Text(
                '200',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _ExternalLinkRow — shortcut buka Muse Asia / Ani-One Asia di browser
// ─────────────────────────────────────────────────────────────────────────

class _ExternalLinkRow extends StatelessWidget {
  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _shortcut('Muse Asia', 'https://www.youtube.com/@MuseAsia/videos'),
        const SizedBox(width: 8),
        _shortcut('Ani-One Asia', 'https://www.youtube.com/@Ani-OneAsia'),
      ],
    );
  }

  Widget _shortcut(String label, String url) {
    return TextButton.icon(
      onPressed: () => _open(url),
      icon: const Icon(Icons.open_in_new, size: 12),
      label: Text(
        label,
        style: GoogleFonts.roboto(fontSize: 11, color: AppColors.primary),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _AnimePreviewBadge — show judul anime hasil resolve dari AniList ID
// ─────────────────────────────────────────────────────────────────────────

class _AnimePreviewBadge extends StatelessWidget {
  const _AnimePreviewBadge({required this.anime, required this.isLoading});

  final Anime? anime;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.adminSearchingAniList,
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      );
    }
    if (anime == null) return const SizedBox.shrink();

    final epLabel = anime!.episodes != null ? ' · ${anime!.episodes} eps' : '';
    final formatLabel = anime!.format != null ? ' · ${anime!.format}' : '';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${anime!.title}$formatLabel$epLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
