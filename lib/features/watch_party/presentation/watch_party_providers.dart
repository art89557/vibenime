import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_message.dart';
import '../data/watch_party.dart';
import '../data/watch_party_repository.dart';

/// Async list active parties untuk anime tertentu.
///
/// Dipakai di Detail screen untuk show "Pesta Nonton EP X" card.
/// Kalau list kosong → user bisa "Mulai Pesta Nonton" baru.
/// Kalau list ada → user bisa "Join" salah satu.
final activePartiesProvider = FutureProvider.family
    .autoDispose<List<WatchParty>, int>((ref, animeId) {
      final repo = ref.watch(watchPartyRepositoryProvider);
      return repo.activeParties(animeId: animeId);
    });

/// Stream party state — auto-refresh saat host update playback.
///
/// Dipakai di WatchPartyScreen untuk:
/// - Sync viewer ke posisi host (auto-seek kalau diff > 3 detik)
/// - Detect party ended (host call endParty atau is_active=false)
final partyStreamProvider = StreamProvider.family
    .autoDispose<WatchParty, String>((ref, partyId) {
      final repo = ref.watch(watchPartyRepositoryProvider);
      return repo.watchParty(partyId);
    });

/// Stream chat messages untuk party tertentu.
///
/// Auto-emit saat ada message baru via Supabase Realtime.
/// Order: ascending by created_at (newest at bottom of list).
final chatStreamProvider = StreamProvider.family
    .autoDispose<List<ChatMessage>, String>((ref, partyId) {
      final repo = ref.watch(watchPartyRepositoryProvider);
      return repo.watchChat(partyId);
    });
