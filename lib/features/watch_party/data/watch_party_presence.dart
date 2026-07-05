import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper Supabase Realtime Channel untuk track viewer presence di Watch Party.
///
/// **Cara kerja:**
/// 1. Tiap viewer (host + viewer) yang masuk WatchPartyScreen panggil [join]
///    dengan `partyId` + identity.
/// 2. Channel `party_{partyId}` di-subscribe + presence di-track via
///    `RealtimeChannel.track()`.
/// 3. Saat ada client lain join/leave, [onPresenceSync] dipicu — kita hitung
///    total presences dari `presenceState()` dan emit ke stream.
/// 4. Saat dispose, [leave] untrack + unsubscribe — Supabase auto-broadcast
///    perubahan ke client lain.
///
/// **Kenapa Realtime Presence?**
/// - Auto-cleanup pas disconnect (gak perlu DELETE manual)
/// - Ephemeral — match karakter Watch Party (session-scoped)
/// - Single source of truth untuk count, gak perlu polling
class WatchPartyPresence {
  WatchPartyPresence(this._client);

  final SupabaseClient _client;

  RealtimeChannel? _channel;
  StreamController<int>? _countController;

  /// Subscribe ke channel + track presence. Return `Stream<int>` count viewer.
  ///
  /// Caller wajib [leave] saat tidak butuh lagi (dispose).
  Stream<int> join({
    required String partyId,
    required String viewerId,
    required String username,
  }) {
    _countController = StreamController<int>.broadcast();
    _channel = _client.channel('party_$partyId');

    _channel!.onPresenceSync((_) => _emitCount());
    _channel!.onPresenceJoin((_) => _emitCount());
    _channel!.onPresenceLeave((_) => _emitCount());

    _channel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await _channel!.track({
            'viewer_id': viewerId,
            'username': username,
            'joined_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('WatchPartyPresence track error: $e');
        }
      }
      if (error != null) {
        debugPrint('WatchPartyPresence channel error: $error');
      }
    });

    // Emit initial 1 (current viewer) supaya UI tidak stuck di 0
    _countController!.add(1);

    return _countController!.stream;
  }

  /// Hitung jumlah total presences di channel dan emit ke stream.
  ///
  /// `presenceState()` return `List<SinglePresenceState>` di mana tiap entry
  /// punya `presences` list (multiple client per user kalau multi-device).
  /// Total = sum dari semua presences.length.
  void _emitCount() {
    final channel = _channel;
    final controller = _countController;
    if (channel == null || controller == null || controller.isClosed) return;
    try {
      final state = channel.presenceState();
      var count = 0;
      for (final entry in state) {
        count += entry.presences.length;
      }
      // Defensive: minimum 1 (kita sendiri)
      controller.add(count == 0 ? 1 : count);
    } catch (e) {
      debugPrint('WatchPartyPresence presenceState error: $e');
    }
  }

  /// Untrack + unsubscribe. Idempotent (no-op kalau sudah leave).
  Future<void> leave() async {
    try {
      await _channel?.untrack();
    } catch (_) {
      /* best-effort */
    }
    try {
      await _channel?.unsubscribe();
    } catch (_) {
      /* best-effort */
    }
    await _countController?.close();
    _channel = null;
    _countController = null;
  }
}

/// Provider — fresh instance per use (jangan reuse, karena state internal
/// per-party). Pemakaian di WatchPartyScreen: `ref.read(...)` di initState,
/// simpan instance di field, dispose manual.
final watchPartyPresenceProvider = Provider.autoDispose<WatchPartyPresence>(
  (ref) => WatchPartyPresence(Supabase.instance.client),
);
