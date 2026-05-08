import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../config/env.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

/// Wrapper di atas GraphQLClient agar lebih ergonomis dipakai dari repository.
class AniListClient {
  AniListClient(this._client);

  final GraphQLClient _client;

  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    final result = await _client.query(
      QueryOptions(
        document: gql(document),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (result.hasException) {
      throw ApiException(
        message: result.exception?.graphqlErrors.firstOrNull?.message ??
            result.exception?.linkException?.toString() ??
            'GraphQL error',
        source: 'AniList',
      );
    }
    return result.data ?? const {};
  }

  Future<Map<String, dynamic>> mutate(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    final result = await _client.mutate(
      MutationOptions(
        document: gql(document),
        variables: variables,
      ),
    );
    if (result.hasException) {
      throw ApiException(
        message: result.exception?.graphqlErrors.firstOrNull?.message ??
            'GraphQL mutation error',
        source: 'AniList',
      );
    }
    return result.data ?? const {};
  }
}

/// Provider GraphQLClient — token diambil dari secure storage.
final anilistGraphQLClientProvider = Provider<GraphQLClient>((ref) {
  final storage = ref.watch(secureStorageProvider);

  final httpLink = HttpLink(Env.anilistGraphqlEndpoint);
  final authLink = AuthLink(getToken: () async {
    final token = await storage.read(key: SecureStorageKeys.anilistToken);
    return token == null ? null : 'Bearer $token';
  });

  return GraphQLClient(
    link: authLink.concat(httpLink),
    cache: GraphQLCache(),
  );
});

final anilistClientProvider = Provider<AniListClient>(
  (ref) => AniListClient(ref.watch(anilistGraphQLClientProvider)),
);

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
