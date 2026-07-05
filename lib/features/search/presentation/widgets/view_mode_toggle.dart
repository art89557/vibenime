import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../search_providers.dart';
import '../../../../core/theme/app_radius.dart';

/// 3 icon toggle untuk switch view mode (compact / large / list).
///
/// Match AniList browser style — 3 icon button kecil dengan active state
/// highlight (cyan tint background).
class ViewModeToggle extends ConsumerWidget {
  const ViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(viewModeProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleIcon(
          icon: Icons.grid_view_rounded,
          tooltip: 'Compact grid',
          isActive: current == SearchViewMode.compact,
          onTap: () {
            Haptic.selection();
            ref.read(viewModeProvider.notifier).state = SearchViewMode.compact;
          },
        ),
        const SizedBox(width: 2),
        _ToggleIcon(
          icon: Icons.dashboard_rounded,
          tooltip: 'Large grid',
          isActive: current == SearchViewMode.large,
          onTap: () {
            Haptic.selection();
            ref.read(viewModeProvider.notifier).state = SearchViewMode.large;
          },
        ),
        const SizedBox(width: 2),
        _ToggleIcon(
          icon: Icons.view_list_rounded,
          tooltip: 'Detailed list',
          isActive: current == SearchViewMode.list,
          onTap: () {
            Haptic.selection();
            ref.read(viewModeProvider.notifier).state = SearchViewMode.list;
          },
        ),
      ],
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryAdaptive(context).withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive
                ? AppColors.primaryAdaptive(context)
                : AppColors.textMuted(context),
          ),
        ),
      ),
    );
  }
}
