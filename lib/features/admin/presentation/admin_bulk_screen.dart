import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/constants.dart';
import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/source_type.dart';
import '../../player/data/video_catalog_repository.dart';
import 'admin_providers.dart';
import 'widgets/url_pattern_helper.dart';
import '../../../core/theme/app_radius.dart';

/// Mode input bulk insert.
enum _BulkMode { pattern, pasteList }

/// Layar untuk bulk insert banyak video source sekaligus — polished v2.
///
/// **Layout sectioned cards** (konsisten dengan AdminFormScreen):
/// 1. **Anime** — AniList ID + Mode toggle (Pattern/Paste List)
/// 2. **Pattern/List** — input URL pattern atau paste list (sesuai mode)
/// 3. **Source** — visual source type picker
/// 4. **Metadata** — Quality chips, Priority slider, Notes prefix
/// 5. **Preview** — list URL yang akan di-insert (sticky di bawah saat ada)
///
/// Sticky bottom action: Preview button → Generate N Entries button.
class AdminBulkScreen extends ConsumerStatefulWidget {
  const AdminBulkScreen({super.key});

  @override
  ConsumerState<AdminBulkScreen> createState() => _AdminBulkScreenState();
}

class _AdminBulkScreenState extends ConsumerState<AdminBulkScreen> {
  _BulkMode _mode = _BulkMode.pattern;

  // Common fields
  final _anilistIdCtrl = TextEditingController();
  final _notesPrefixCtrl = TextEditingController();
  String _quality = '480p';
  SourceType _sourceType = SourceType.archiveOrg;
  int _priority = PaginationConstants.defaultSourcePriority;

  // Pattern mode
  final _episodeFromCtrl = TextEditingController(text: '1');
  final _episodeToCtrl = TextEditingController(text: '5');
  final _patternCtrl = TextEditingController();

  // Paste list mode
  final _episodeStartCtrl = TextEditingController(text: '1');
  final _pasteListCtrl = TextEditingController();

  // Preview state
  List<String>? _previewUrls;
  String? _previewError;
  bool _saving = false;

  static const _qualities = ['240p', '360p', '480p', '720p', '1080p', 'auto'];

  @override
  void dispose() {
    _anilistIdCtrl.dispose();
    _notesPrefixCtrl.dispose();
    _episodeFromCtrl.dispose();
    _episodeToCtrl.dispose();
    _patternCtrl.dispose();
    _episodeStartCtrl.dispose();
    _pasteListCtrl.dispose();
    super.dispose();
  }

  /// Build preview list URL berdasar mode aktif.
  void _buildPreview() {
    Haptic.light();
    setState(() {
      _previewError = null;
      _previewUrls = null;
    });

    try {
      List<String> urls;
      if (_mode == _BulkMode.pattern) {
        final from = int.tryParse(_episodeFromCtrl.text.trim()) ?? 0;
        final to = int.tryParse(_episodeToCtrl.text.trim()) ?? 0;
        urls = generatePatternUrls(
          pattern: _patternCtrl.text.trim(),
          from: from,
          to: to,
        );
      } else {
        urls = parseUrlList(_pasteListCtrl.text);
        if (urls.isEmpty) {
          throw FormatException(context.l10n.adminEmptyUrlList);
        }
      }
      setState(() => _previewUrls = urls);
    } catch (e) {
      final msg = e is FormatException ? e.message : e.toString();
      setState(() => _previewError = msg);
    }
  }

  /// Save semua URL ke Supabase via [VideoCatalogRepository.insertMany].
  Future<void> _save() async {
    final urls = _previewUrls;
    if (urls == null || urls.isEmpty) return;

    final anilistId = int.tryParse(_anilistIdCtrl.text.trim());
    if (anilistId == null || anilistId <= 0) {
      AppSnackbar.error(context, context.l10n.adminValIdPositive);
      return;
    }

    final episodeStart = _mode == _BulkMode.pattern
        ? (int.tryParse(_episodeFromCtrl.text.trim()) ?? 1)
        : (int.tryParse(_episodeStartCtrl.text.trim()) ?? 1);

    final notesPrefix = _notesPrefixCtrl.text.trim();

    final sources = <VideoSource>[];
    for (int i = 0; i < urls.length; i++) {
      final ep = episodeStart + i;
      sources.add(
        VideoSource(
          id: '', // server-generated
          anilistId: anilistId,
          episodeNumber: ep,
          videoUrl: urls[i],
          sourceType: _sourceType.value,
          quality: _quality,
          priority: _priority,
          notes: notesPrefix.isEmpty ? null : '$notesPrefix $ep',
        ),
      );
    }

    Haptic.medium();
    setState(() => _saving = true);
    try {
      final repo = ref.read(videoCatalogRepositoryProvider);
      final saved = await repo.insertMany(sources);
      ref.invalidate(adminVideoSourcesProvider);
      if (!mounted) return;
      AppSnackbar.success(context, context.l10n.adminVideosSaved(saved.length));
      context.pop();
    } catch (e) {
      AppSnackbar.error(context, context.l10n.adminFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _previewUrls != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              NavHelper.safePop(context, fallback: AppRoutes.adminPanel),
        ),
        title: Text(
          'Bulk Insert',
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              // Section 1: Anime
              _SectionCard(
                title: 'Anime',
                icon: Icons.movie_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('AniList ID'),
                    TextField(
                      controller: _anilistIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: context.l10n.adminIdHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Section 2: Mode + URLs input
              _SectionCard(
                title: 'URL Input',
                icon: Icons.list_alt_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ModeToggle(
                      mode: _mode,
                      onChange: (m) => setState(() {
                        _mode = m;
                        _previewUrls = null;
                        _previewError = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    if (_mode == _BulkMode.pattern)
                      _patternFields()
                    else
                      _pasteListFields(),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Section 3: Source Type
              _SectionCard(
                title: 'Source',
                icon: Icons.video_settings_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Source Type'),
                    _SourceTypeChips(
                      selected: _sourceType,
                      onSelected: (t) => setState(() => _sourceType = t),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Section 4: Metadata
              _SectionCard(
                title: 'Metadata',
                icon: Icons.tune_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                ),
              ),
              const SizedBox(height: 12),

              // Section 5: Notes
              _SectionCard(
                title: 'Notes Prefix',
                icon: Icons.notes_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _notesPrefixCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Astro Boy 1963 — EP',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.adminNotesPrefixHint,
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Error display
              if (_previewError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _previewError!,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Preview list
              if (hasPreview) ...[
                _SectionCard(
                  title: 'Preview · ${_previewUrls!.length} entries',
                  icon: Icons.preview_rounded,
                  child: _PreviewList(
                    urls: _previewUrls!,
                    episodeStart: _mode == _BulkMode.pattern
                        ? (int.tryParse(_episodeFromCtrl.text.trim()) ?? 1)
                        : (int.tryParse(_episodeStartCtrl.text.trim()) ?? 1),
                  ),
                ),
              ],
            ],
          ),

          // Sticky bottom action bar
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
              child: hasPreview
                  ? Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _buildPreview,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Refresh'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: BorderSide(
                                color: AppColors.borderColor(context),
                              ),
                              foregroundColor: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onAccent,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(
                              _saving
                                  ? context.l10n.adminSaving
                                  : context.l10n.adminInsertN(
                                      _previewUrls!.length,
                                    ),
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onAccent,
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _buildPreview,
                        icon: const Icon(Icons.preview_rounded, size: 18),
                        label: Text(
                          'Preview URLs',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onAccent,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _patternFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(context.l10n.adminEpisodeFrom),
                  TextField(
                    controller: _episodeFromCtrl,
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
                  _Label(context.l10n.adminEpisodeTo),
                  TextField(
                    controller: _episodeToCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '5'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _Label('URL Pattern'),
        TextField(
          controller: _patternCtrl,
          maxLines: 2,
          minLines: 1,
          autocorrect: false,
          style: GoogleFonts.jetBrainsMono(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'https://archive.org/.../E{ep:03d}.mp4',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PLACEHOLDER',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '{ep}      → 1, 2, 3, …\n'
                '{ep:02d}  → 01, 02, 03, …\n'
                '{ep:03d}  → 001, 002, 003, …',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppColors.textMuted(context),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pasteListFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(context.l10n.adminStartFromEpisode),
        TextField(
          controller: _episodeStartCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '1'),
        ),
        const SizedBox(height: 14),
        _Label(context.l10n.adminUrlListLabel),
        TextField(
          controller: _pasteListCtrl,
          maxLines: 10,
          minLines: 6,
          autocorrect: false,
          style: GoogleFonts.jetBrainsMono(fontSize: 11),
          decoration: InputDecoration(
            hintText: context.l10n.adminPasteListHint,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.adminPasteNote,
          style: GoogleFonts.roboto(
            fontSize: 11,
            color: AppColors.textMuted(context),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _SectionCard — wrapper konsisten dengan AdminFormScreen
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
// _ModeToggle — segmented control Pattern / Paste List
// ─────────────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChange});

  final _BulkMode mode;
  final ValueChanged<_BulkMode> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              icon: Icons.format_indent_increase_rounded,
              label: 'Pattern',
              isActive: mode == _BulkMode.pattern,
              onTap: () {
                Haptic.selection();
                onChange(_BulkMode.pattern);
              },
            ),
          ),
          Expanded(
            child: _ToggleButton(
              icon: Icons.content_paste_rounded,
              label: 'Paste List',
              isActive: mode == _BulkMode.pasteList,
              onTap: () {
                Haptic.selection();
                onChange(_BulkMode.pasteList);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? AppColors.onAccent
                  : AppColors.textMuted(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.onAccent
                    : AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _SourceTypeChips — visual picker dengan icon (sama dengan form screen)
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
// _QualityChips — pill chips compact (sama dengan form screen)
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
// _PrioritySlider — slider color-coded (sama dengan form screen)
// ─────────────────────────────────────────────────────────────────────────

class _PrioritySlider extends StatelessWidget {
  const _PrioritySlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _PreviewList — list URL preview dengan EP badge + truncate
// ─────────────────────────────────────────────────────────────────────────

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.urls, required this.episodeStart});

  final List<String> urls;
  final int episodeStart;

  static const _maxVisible = 10;

  @override
  Widget build(BuildContext context) {
    final visible = urls.take(_maxVisible).toList();
    final overflow = urls.length - _maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++)
                _PreviewRow(
                  episode: episodeStart + i,
                  url: visible[i],
                  isLast: i == visible.length - 1 && overflow <= 0,
                ),
              if (overflow > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.borderColor(context)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.more_horiz_rounded,
                        size: 14,
                        color: AppColors.textMuted(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.adminMoreEntries(overflow),
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.episode,
    required this.url,
    required this.isLast,
  });

  final int episode;
  final String url;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.borderColor(context),
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.tiny),
            ),
            child: Text(
              'EP ${episode.toString().padLeft(2, '0')}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                color: AppColors.textMuted(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
