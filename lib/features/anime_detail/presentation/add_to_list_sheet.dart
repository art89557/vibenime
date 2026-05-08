import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../my_list/data/my_list_repository.dart';
import '../../my_list/presentation/my_list_providers.dart';
import '../data/list_mutation_repository.dart';

const _statusOptions = <ListStatus>[
  ListStatus.current,
  ListStatus.planning,
  ListStatus.completed,
  ListStatus.paused,
  ListStatus.dropped,
];

const _statusIcons = <ListStatus, IconData>{
  ListStatus.current: Icons.play_circle_outline_rounded,
  ListStatus.planning: Icons.schedule_rounded,
  ListStatus.completed: Icons.check_circle_outline_rounded,
  ListStatus.paused: Icons.pause_circle_outline_rounded,
  ListStatus.dropped: Icons.cancel_outlined,
};

/// Tampilkan bottom sheet untuk pilih status list. Return true kalau berhasil.
Future<bool> showAddToListSheet({
  required BuildContext context,
  required int mediaId,
  required String title,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surfaceDarkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddToListSheet(mediaId: mediaId, title: title),
  );
  return result ?? false;
}

class _AddToListSheet extends ConsumerStatefulWidget {
  const _AddToListSheet({required this.mediaId, required this.title});

  final int mediaId;
  final String title;

  @override
  ConsumerState<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends ConsumerState<_AddToListSheet> {
  bool _saving = false;

  Future<void> _save(ListStatus status) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(listMutationRepositoryProvider).setStatus(
            mediaId: widget.mediaId,
            status: status,
          );
      ref.invalidate(myListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ditambahkan ke "${status.label}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textOnDarkMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tambah ke list',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textOnDarkMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._statusOptions.map(
              (s) => ListTile(
                leading: Icon(_statusIcons[s], color: AppColors.primary),
                title: Text(s.label),
                trailing: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () => _save(s),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
