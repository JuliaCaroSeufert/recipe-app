import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up a real food photo for [query] via Openverse — a free, **keyless**
/// search over openly-licensed images (Wikimedia, Flickr, …). Returns a usable
/// image URL or null. Never throws.
///
/// No API key required; Openverse proxies a stable, CORS-friendly thumbnail.
Future<String?> fetchFoodPhotoUrl(String query) async {
  try {
    final uri = Uri.parse(
      'https://api.openverse.org/v1/images/'
      '?q=${Uri.encodeQueryComponent('$query food dish')}'
      '&page_size=1&mature=false',
    );
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'Essensplan/1.0 (meal planner app)',
    }).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'] as List?;
    if (results == null || results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    // Prefer the Openverse-proxied thumbnail (reliable, resized, CORS-ok),
    // fall back to the original image URL.
    final thumb = first['thumbnail'];
    final url = first['url'];
    if (thumb is String && thumb.isNotEmpty) return thumb;
    if (url is String && url.isNotEmpty) return url;
    return null;
  } catch (_) {
    return null;
  }
}
