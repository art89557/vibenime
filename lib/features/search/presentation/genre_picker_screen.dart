import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import 'search_providers.dart';
import '../../../core/theme/app_radius.dart';

/// Mood / Genre picker — sumber data canonical AniList GenreCollection.
///
/// AniList genre list relatif stabil (jarang berubah) dan terdokumentasi,
/// jadi di-hardcode di sini sebagai single source of truth. Update kalau
/// AniList tambah genre baru.
///
/// Reference: https://anilist.co/search/anime (sidebar Genres)
///
/// **UX:**
/// - Multi-select dengan checkbox visual (border cyan + ✓)
/// - "Hapus filter" muncul kalau ada selection awal (dari state global)
/// - "Terapkan · N dipilih" di bottom — return ke Search dengan filter aktif
class GenrePickerScreen extends ConsumerStatefulWidget {
  const GenrePickerScreen({super.key});

  @override
  ConsumerState<GenrePickerScreen> createState() => _GenrePickerScreenState();
}

class _GenrePickerScreenState extends ConsumerState<GenrePickerScreen> {
  late final Set<String> _selected;

  /// Canonical AniList anime genres dengan icon emoji untuk visual.
  ///
  /// **Penting:** value (kanan) HARUS exact match dengan AniList API genre
  /// strings (case-sensitive). Kalau salah typo → filter tidak match.
  static const List<_GenreData> _genres = [
    _GenreData('Action', '🗡️', 'Action'),
    _GenreData('Adventure', '🧭', 'Adventure'),
    _GenreData('Comedy', '😂', 'Comedy'),
    _GenreData('Drama', '🎭', 'Drama'),
    _GenreData('Ecchi', '💋', 'Ecchi'),
    _GenreData('Fantasy', '🧙', 'Fantasy'),
    _GenreData('Horror', '👻', 'Horror'),
    _GenreData('Mahou Shoujo', '✨', 'Mahou Shoujo'),
    _GenreData('Mecha', '🤖', 'Mecha'),
    _GenreData('Music', '🎵', 'Music'),
    _GenreData('Mystery', '🔍', 'Mystery'),
    _GenreData('Psychological', '🧠', 'Psychological'),
    _GenreData('Romance', '💖', 'Romance'),
    _GenreData('Sci-Fi', '🚀', 'Sci-Fi'),
    _GenreData('Slice of Life', '☕', 'Slice of Life'),
    _GenreData('Sports', '⚽', 'Sports'),
    _GenreData('Supernatural', '🔮', 'Supernatural'),
    _GenreData('Thriller', '🗲', 'Thriller'),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-load selection state dari provider supaya UX consistent saat user
    // re-open picker setelah set filter sebelumnya.
    _selected = {...ref.read(selectedGenresProvider)};
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (hasSelection)
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: Text(
                context.l10n.genrePickerClear,
                style: GoogleFonts.roboto(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              context.l10n.genrePickerTitle,
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Text(
              context.l10n.genrePickerSubtitle,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textMuted(context),
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
            ),
            itemCount: _genres.length,
            itemBuilder: (_, i) {
              final g = _genres[i];
              final isSelected = _selected.contains(g.value);
              return _GenreCard(
                data: g,
                isSelected: isSelected,
                onTap: () {
                  Haptic.selection();
                  setState(() {
                    if (isSelected) {
                      _selected.remove(g.value);
                    } else {
                      _selected.add(g.value);
                    }
                  });
                },
              );
            },
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Haptic.medium();
                  // Update global filter state — searchResultsProvider akan
                  // auto-refetch karena watch selectedGenresProvider.
                  ref.read(selectedGenresProvider.notifier).state = _selected
                      .toList();
                  context.pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface(context),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  hasSelection
                      ? context.l10n.genrePickerApply(_selected.length)
                      : context.l10n.genrePickerShowAll,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Pasangan label display + value AniList API.
class _GenreData {
  const _GenreData(this.name, this.icon, this.value);

  /// Display label di UI (bisa dilokalisasi ke ID kalau perlu).
  final String name;

  /// Emoji icon untuk hint visual.
  final String icon;

  /// String value yang dikirim ke AniList GraphQL `genre_in` — case-sensitive.
  final String value;
}

class _GenreCard extends StatelessWidget {
  const _GenreCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _GenreData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.borderColor(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data.icon, style: const TextStyle(fontSize: 24)),
                Text(
                  data.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
