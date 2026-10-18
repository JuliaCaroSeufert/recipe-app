import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up a real food photo for [query] via the free Pexels API.
/// Returns a usable image URL or null. Never throws.
Future<String?> fetchPexelsPhotoUrl(String query, String apiKey) async {
  if (apiKey.trim().isEmpty) return null;
  try {
    final uri = Uri.parse(
      'https://api.pexels.com/v1/search'
      '?per_page=1&orientation=landscape'
      '&query=${Uri.encodeQueryComponent(query)}',
    );
    final res = await http
        .get(uri, headers: {'Authorization': apiKey.trim()})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final photos = json['photos'] as List?;
    if (photos == null || photos.isEmpty) return null;
    final src = (photos.first as Map)['src'] as Map?;
    final url = src?['large'] ?? src?['medium'] ?? src?['original'];
    return url is String ? url : null;
  } catch (_) {
    return null;
  }
}
