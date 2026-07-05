import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/env.dart';
import '../storage/hive_init.dart';
import 'api_exception.dart';

/// Wrapper di atas GraphQLClient agar lebih ergonomis dipakai dari repository.
///
/// **Cache offline:** respons query non-search (fetchPolicy != noCache) di-
/// simpan persisten ke Hive ([_cacheBox]) secara write-through. Kalau request
/// **gagal karena jaringan** dan ada salinan cache → serve stale (browsing
/// tetap jalan offline / saat AniList down) alih-alih melempar error.
class AniListClient {
  AniListClient(this._client, {Box<String>? cacheBox}) : _cacheBox = cacheBox;

  final GraphQLClient _client;
  final Box<String>? _cacheBox;

  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
    FetchPolicy fetchPolicy = FetchPolicy.cacheFirst,
  }) async {
    // Search (noCache) bersifat dinamis → jangan persist/serve stale.
    final persist = fetchPolicy != FetchPolicy.noCache;
    final key = persist ? cacheKey(document, variables) : null;

    QueryResult<Object?> result;
    try {
      result = await _client.query(
        QueryOptions(
          document: gql(document),
          variables: variables,
          // Default `cacheFirst` cocok untuk static data (detail anime,
          // trending). Search dynamic harus pakai `networkOnly` supaya tidak
          // serve stale empty cache.
          fetchPolicy: fetchPolicy,
        ),
      );
    } catch (e) {
      // Exception tak terduga (mis. koneksi putus di tengah) → coba cache.
      final cached = key == null ? null : _readCache(key);
      if (cached != null) return cached;
      rethrow;
    }

    if (result.hasException) {
      // Gagal (rate-limit / offline / dll) → serve cache stale kalau ada.
      final cached = key == null ? null : _readCache(key);
      if (cached != null) return cached;
      throw ApiException(
        message: _friendlyErrorMessage(result.exception),
        source: 'AniList',
      );
    }

    final data = result.data ?? const <String, dynamic>{};
    if (key != null && data.isNotEmpty) _writeCache(key, data);
    return data;
  }

  /// Kunci cache stabil dari [document] + [variables] (urutan variable tidak
  /// berpengaruh). Pure → mudah di-test.
  static String cacheKey(String document, Map<String, dynamic> variables) {
    final sortedKeys = variables.keys.toList()..sort();
    final varsStr = sortedKeys.map((k) => '$k=${variables[k]}').join('&');
    return '${document.hashCode}|$varsStr';
  }

  Map<String, dynamic>? _readCache(String key) {
    final box = _cacheBox;
    if (box == null) return null;
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (decoded['data'] as Map?)?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  void _writeCache(String key, Map<String, dynamic> data) {
    final box = _cacheBox;
    if (box == null) return;
    try {
      box.put(
        key,
        jsonEncode({'ts': DateTime.now().millisecondsSinceEpoch, 'data': data}),
      );
    } catch (e) {
      debugPrint('anilist cache write failed: $e');
    }
  }

  /// Parse error GraphQL/network ke pesan ramah user.
  ///
  /// Kasus yang di-handle:
  /// - **Rate limit (429)** → "Terlalu banyak request. Tunggu sebentar..."
  /// - **No internet** → "Tidak ada koneksi internet. Cek WiFi/data."
  /// - **Host lookup fail** → "Server AniList tidak bisa dijangkau."
  /// - **Default** → message dari server atau "Terjadi kesalahan."
  static String _friendlyErrorMessage(OperationException? exc) {
    if (exc == null) return 'Terjadi kesalahan.';

    // GraphQL errors (mis. 429 Too Many Requests, validation errors)
    final gqlError = exc.graphqlErrors.firstOrNull;
    if (gqlError != null) {
      final msg = gqlError.message.toLowerCase();
      if (msg.contains('too many requests') || msg.contains('rate limit')) {
        return 'AniList rate-limit kena. Tunggu ~1 menit lalu coba lagi.';
      }
      return gqlError.message;
    }

    // Network/link errors
    final linkExc = exc.linkException?.toString().toLowerCase() ?? '';
    if (linkExc.contains('socketexception') ||
        linkExc.contains('failed host lookup') ||
        linkExc.contains('no address associated')) {
      return 'Tidak ada koneksi internet. Cek WiFi/data lalu coba lagi.';
    }
    if (linkExc.contains('timeout')) {
      return 'Koneksi lambat — request timeout. Coba lagi.';
    }
    if (linkExc.contains('429')) {
      return 'Server AniList sibuk. Tunggu ~1 menit lalu coba lagi.';
    }

    return 'Terjadi kesalahan jaringan.';
  }

  Future<Map<String, dynamic>> mutate(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    final result = await _client.mutate(
      MutationOptions(document: gql(document), variables: variables),
    );
    if (result.hasException) {
      throw ApiException(
        message:
            result.exception?.graphqlErrors.firstOrNull?.message ??
            'GraphQL mutation error',
        source: 'AniList',
      );
    }
    return result.data ?? const {};
  }
}

/// Provider GraphQLClient — anonymous-only (public catalog queries).
///
/// Sebelumnya inject AuthLink dengan AniList Bearer token untuk user
/// queries (My List sync). Sejak fitur sync dihapus, semua query AniList
/// jadi public-only — tidak butuh header Authorization.
final anilistGraphQLClientProvider = Provider<GraphQLClient>((ref) {
  final httpLink = HttpLink(Env.anilistGraphqlEndpoint);
  return GraphQLClient(link: httpLink, cache: GraphQLCache());
});

final anilistClientProvider = Provider<AniListClient>((ref) {
  // Box cache offline — null kalau Hive belum di-init (mis. sebagian test).
  Box<String>? cacheBox;
  try {
    cacheBox = Hive.box<String>(HiveBoxes.anilistCache);
  } catch (_) {
    cacheBox = null;
  }
  return AniListClient(
    ref.watch(anilistGraphQLClientProvider),
    cacheBox: cacheBox,
  );
});

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
