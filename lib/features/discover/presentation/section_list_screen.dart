import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav_helper.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../data/anime_repository.dart';
import 'discover_providers.dart';

/// Full-screen list dengan infinite scroll untuk satu section.
/// Dipakai saat user tap "Lihat semua" di Home.
class SectionListScreen extends ConsumerStatefulWidget {
  const SectionListScreen({super.key, required this.section});

  final DiscoverSection section;

  @override
  ConsumerState<SectionListScreen> createState() => _SectionListScreenState();
}

class _SectionListScreenState extends ConsumerState<SectionListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Trigger loadMore kalau scroll dekat bottom (800px sebelum end —
  /// pre-fetch untuk smooth scroll, no spinner saat user scroll cepat).
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 800;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(paginatedDiscoverProvider(widget.section).notifier).loadMore();
    }
  }

  String _sectionTitle(DiscoverSection s) {
    switch (s) {
      case DiscoverSection.trending:
        return context.l10n.discoverTrending;
      case DiscoverSection.popular:
        return context.l10n.discoverPopular;
      case DiscoverSection.topRated:
        return context.l10n.discoverTopRated;
      case DiscoverSection.upcoming:
        return context.l10n.discoverUpcoming;
      case DiscoverSection.completed:
        return 'Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedDiscoverProvider(widget.section));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context, fallback: AppRoutes.home),
        ),
        title: Text(
          _sectionTitle(widget.section),
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(PaginatedAnimeState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetry(
        message: state.error.toString(),
        onRetry: () => ref
            .read(paginatedDiscoverProvider(widget.section).notifier)
            .loadInitial(),
      );
    }
    if (state.items.isEmpty) {
      return Center(
        child: Text(
          context.l10n.discoverEmpty,
          style: GoogleFonts.roboto(color: AppColors.textMuted(context)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(paginatedDiscoverProvider(widget.section).notifier)
          .refresh(),
      child: ResponsiveContainer(
        child: GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Breakpoints.columnsFor(context),
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            // 0.48 — selaras grid Search/Completed; 0.52 overflow di device.
            childAspectRatio: 0.48,
          ),
          // +1 untuk slot loading spinner di akhir kalau hasMore
          itemCount: state.items.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              // Loading footer
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final anime = state.items[index];
            return AnimeCard(
              anime: anime,
              width: double.infinity,
              onTap: () =>
                  context.push(AppRoutes.animeDetailPath(anime.id.toString())),
            );
          },
        ),
      ),
    );
  }
}
