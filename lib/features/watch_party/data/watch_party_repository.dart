import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import 'chat_message.dart';
import 'watch_party.dart';

/// Repository untuk Watch Party — wrap Supabase real-time channels.
///
/// Workflow:
/// - **Host**:
///   1. [createParty] → row baru di `watch_parties`
///   2. Tiap 2 detik panggil [updatePlayback] untuk broadcast position
///   3. Saat selesai → [endParty]
/// - **Viewer**:
///   1. Subscribe ke [watchParty] stream untuk receive party state changes
///   2. Subscribe ke [watchChat] stream untuk receive chat messages
///   3. Send chat via [sendMessage]
///
/// Realtime: pakai Supabase Postgres CDC (Change Data Capture) — listen
/// INSERT/UPDATE event di tabel via `onPostgresChanges`.
class WatchPartyRepository {
  static const String _partyTable = 'watch_parties';
  static const String _chatTable = 'chat_messages';

  /// Mulai party baru sebagai host.
  ///
  /// Return [WatchParty] dengan ID auto-generated dari Supabase.
  /// Throw exception kalau:
  /// - User belum login Supabase (RLS reject)
  /// - Network error
  Future<WatchParty> createParty({
    required int animeId,
    required int episodeNumber,
    required String hostUsername,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Login Supabase dulu untuk mulai pesta nonton.');
    }

    final response = await Supabase.instance.client
        .from(_partyTable)
        .insert({
          'host_user_id': user.id,
          'host_username': hostUsername,
          'anime_id': animeId,
          'episode_number': episodeNumber,
          'current_position_seconds': 0,
          'is_playing': true,
          'is_active': true,
          'participant_count': 1,
        })
        .select()
        .single();

    return WatchParty.fromJson(response);
  }

  /// Update host playback state (call dari player saat play/pause/seek).
  ///
  /// Hanya host yang bisa call (RLS enforce). Update juga `updated_at` via trigger.
  Future<void> updatePlayback({
    required String partyId,
    required int positionSeconds,
    required bool isPlaying,
  }) async {
    await Supabase.instance.client
        .from(_partyTable)
        .update({
          'current_position_seconds': positionSeconds,
          'is_playing': isPlaying,
        })
        .eq('id', partyId);
  }

  /// Akhiri party (host only). Set `is_active=false` supaya viewer disconnect.
  Future<void> endParty(String partyId) async {
    await Supabase.instance.client
        .from(_partyTable)
        .update({'is_active': false})
        .eq('id', partyId);
  }

  /// Stream party state — emit setiap kali host update playback.
  ///
  /// Pakai Supabase Postgres CDC: listen UPDATE event di tabel filter by id.
  Stream<WatchParty> watchParty(String partyId) {
    final controller = Supabase.instance.client
        .from(_partyTable)
        .stream(primaryKey: ['id'])
        .eq('id', partyId);

    return controller.map((rows) {
      if (rows.isEmpty) {
        throw StateError('Party tidak ditemukan / sudah berakhir');
      }
      return WatchParty.fromJson(rows.first);
    });
  }

  /// Stream chat messages — emit semua message party terbaru, sorted ASC by time.
  ///
  /// Initial load fetch existing messages, lalu append message baru via
  /// realtime listener.
  Stream<List<ChatMessage>> watchChat(String partyId) {
    return Supabase.instance.client
        .from(_chatTable)
        .stream(primaryKey: ['id'])
        .eq('party_id', partyId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .cast<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .toList(),
        );
  }

  /// Post chat message ke party. Trigger realtime broadcast ke viewer.
  Future<void> sendMessage({
    required String partyId,
    required String username,
    required String message,
    String type = 'text',
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Login dulu untuk chat.');
    }
    await Supabase.instance.client.from(_chatTable).insert({
      'party_id': partyId,
      'user_id': user.id,
      'username': username,
      'message': message,
      'type': type,
    });
  }

  /// Single fetch active parties untuk anime tertentu.
  /// Dipakai oleh "Pesta Nonton" card di Detail screen.
  Future<List<WatchParty>> activeParties({required int animeId}) async {
    if (!Env.isSupabaseConfigured) return const [];
    try {
      final response = await Supabase.instance.client
          .from(_partyTable)
          .select()
          .eq('anime_id', animeId)
          .eq('is_active', true)
          .order('started_at', ascending: false)
          .limit(5);

      return (response as List)
          .cast<Map<String, dynamic>>()
          .map(WatchParty.fromJson)
          .toList();
    } catch (e) {
      debugPrint('activeParties error: $e');
      return const [];
    }
  }

  /// Get single party by ID (untuk initial load di WatchPartyScreen).
  Future<WatchParty?> getParty(String partyId) async {
    if (!Env.isSupabaseConfigured) return null;
    try {
      final response = await Supabase.instance.client
          .from(_partyTable)
          .select()
          .eq('id', partyId)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      return WatchParty.fromJson(response);
    } catch (e) {
      debugPrint('getParty error: $e');
      return null;
    }
  }
}

final watchPartyRepositoryProvider = Provider<WatchPartyRepository>(
  (ref) => WatchPartyRepository(),
);
