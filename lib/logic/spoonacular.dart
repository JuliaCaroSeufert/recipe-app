import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe.dart';

/// Spoonacular photo integration.
///
/// The pure helpers ([spoonacularQuery], [parseSpoonacularImage],
/// [bestSpoonacularImageUrl]) have no Flutter/http dependency and are unit
/// tested. [fetchSpoonacularImage] performs the one network call (mirrors the
/// pattern in `ai_import.dart`). The image host `img.spoonacular.com` serves
/// pictures at predictable sizes by id, and renders fine in the browser via
/// the `<img>` path in `net_image_web.dart`.

/// Thrown with a user-friendly message for the UI.
class SpoonacularException implements Exception {
  final String message;
  SpoonacularException(this.message);
  @override
  String toString() => message;
}

/// Short English search query for a recipe, from its photo keywords (which
/// already map common German food words to English). Falls back to the title.
String spoonacularQuery(Recipe r) {
  final words = r.photoKeywords
      .split(',')
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty && w != 'food' && w != 'meal')
      .toList();
  final q = words.take(3).join(' ').trim();
  return q.isEmpty ? r.title : q;
}

/// Picks the best image URL from a `complexSearch` response body, upgraded to a
/// crisp size. Returns null when there is no usable result.
String? parseSpoonacularImage(Map<String, dynamic> json) {
  final results = json['results'] as List?;
  if (results == null || results.isEmpty) return null;
  final first = results.first as Map<String, dynamic>;
  return bestSpoonacularImageUrl(
    image: first['image'] as String?,
    id: (first['id'] as num?)?.toInt(),
  );
}

/// Spoonacular serves recipe photos at predictable sizes:
/// `https://img.spoonacular.com/recipes/<id>-636x393.<ext>`. Upgrade whatever
/// size the search returned to 636x393 for sharp tiles. Non-Spoonacular
/// (publisher) URLs are returned unchanged.
String? bestSpoonacularImageUrl({String? image, int? id}) {
  if (image == null || image.isEmpty) {
    return id == null
        ? null
        : 'https://img.spoonacular.com/recipes/$id-636x393.jpg';
  }
  final m = RegExp(r'^(.*/recipes/\d+)-\d+x\d+\.(\w+)$').firstMatch(image);
  if (m != null) return '${m.group(1)}-636x393.${m.group(2)}';
  return image;
}

/// Looks up one photo for [query] via Spoonacular `complexSearch`. Returns the
/// best image URL, or null if nothing matched. Throws [SpoonacularException]
/// with a readable message on auth/quota/network errors.
Future<String?> fetchSpoonacularImage(
  String query, {
  required String apiKey,
  http.Client? client,
}) async {
  if (apiKey.trim().isEmpty) {
    throw SpoonacularException('Kein Spoonacular-Schlüssel hinterlegt.');
  }
  final uri = Uri.https('api.spoonacular.com', '/recipes/complexSearch', {
    'query': query,
    'number': '1',
    'sort': 'popularity',
    'apiKey': apiKey.trim(),
  });

  final http.Client c = client ?? http.Client();
  http.Response res;
  try {
    res = await c.get(uri).timeout(const Duration(seconds: 20));
  } catch (e) {
    throw SpoonacularException('Netzwerkfehler: $e');
  } finally {
    if (client == null) c.close();
  }

  if (res.statusCode == 401) {
    throw SpoonacularException(
        'Spoonacular-Schlüssel ungültig. Prüfe ihn in den Einstellungen.');
  }
  if (res.statusCode == 402) {
    throw SpoonacularException(
        'Spoonacular-Tageslimit erreicht. Morgen weiter laden.');
  }
  if (res.statusCode != 200) {
    throw SpoonacularException(
        'Spoonacular-Fehler (Code ${res.statusCode}).');
  }
  try {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return parseSpoonacularImage(json);
  } catch (e) {
    throw SpoonacularException('Antwort nicht lesbar: $e');
  }
}
