/// Exception umum untuk error API (AniList & Consumet).
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.source,
  });

  final String message;
  final int? statusCode;
  final String? source;

  @override
  String toString() {
    final parts = <String>[
      if (source != null) '[$source]',
      if (statusCode != null) 'HTTP $statusCode',
      message,
    ];
    return 'ApiException: ${parts.join(' ')}';
  }
}
