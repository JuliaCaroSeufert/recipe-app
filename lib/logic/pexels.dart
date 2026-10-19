import 'dart:convert';

import 'package:http/http.dart' as http;

/// Pexels photo lookup — professional, consistent food photography (the look
/// of modern recipe apps). Free key, generous limits. Used to bake beautiful
/// seed photos in CI; images.pexels.com is CORS-friendly so they also render
/// in the browser.

class PexelsException implements Exception {
  final String message;
  PexelsException(this.message);
  @override
  String toString() => message;
}

/// Returns a high-quality landscape photo URL for [query], or null if nothing
/// matched. Throws [PexelsException] on auth/limit/network errors.
Future<String?> fetchPexelsImage(
  String query, {
  required String apiKey,
  http.Client? client,
}) async {
  if (apiKey.trim().isEmpty) {
    throw PexelsException('Kein Pexels-Schlüssel hinterlegt.');
  }
  final uri = Uri.https('api.pexels.com', '/v1/search', {
    'query': '$query food',
    'per_page': '1',
    'orientation': 'landscape',
    'size': 'large',
  });

  final http.Client c = client ?? http.Client();
  http.Response res;
  try {
    res = await c
        .get(uri, headers: {'Authorization': apiKey.trim()})
        .timeout(const Duration(seconds: 20));
  } catch (e) {
    throw PexelsException('Netzwerkfehler: $e');
  } finally {
    if (client == null) c.close();
  }

  if (res.statusCode == 401) {
    throw PexelsException(
        'Pexels-Schlüssel ungültig. Prüfe ihn in den Einstellungen.');
  }
  if (res.statusCode == 429) {
    throw PexelsException('Pexels-Limit erreicht. Später nochmal versuchen.');
  }
  if (res.statusCode != 200) {
    throw PexelsException('Pexels-Fehler (Code ${res.statusCode}).');
  }
  try {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final photos = json['photos'] as List?;
    if (photos == null || photos.isEmpty) return null;
    final src = (photos.first as Map)['src'] as Map?;
    final url = (src?['large2x'] ?? src?['large'] ?? src?['original']);
    return url is String ? url : null;
  } catch (e) {
    throw PexelsException('Antwort nicht lesbar: $e');
  }
}
