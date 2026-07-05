import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/schedule_repository.dart';

/// Selected day di Jadwal screen (default = today).
final selectedScheduleDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Airing schedule untuk hari yang dipilih.
final airingScheduleProvider = FutureProvider.autoDispose<List<AiringItem>>((
  ref,
) async {
  final day = ref.watch(selectedScheduleDayProvider);
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.fetchForDay(day);
});
