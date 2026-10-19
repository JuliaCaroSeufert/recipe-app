import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/household.dart';
import '../models/recipe.dart';

/// Optional build-time Spoonacular key, injected via
/// `--dart-define=SPOONACULAR_KEY=...` (never committed in source). Lets the
/// deployed build ship with photos working out of the box; a user-entered key
/// in Settings still overrides it. Empty when not provided at build time.
const String kBuildSpoonacularKey =
    String.fromEnvironment('SPOONACULAR_KEY');

/// The key to use: the household's own key when set, otherwise the build key.
String effectiveSpoonacularKey(Household h) {
  final own = h.spoonacularApiKey.trim();
  return own.isNotEmpty ? own : kBuildSpoonacularKey.trim();
}

/// True when running on the web (pure-Dart check, no Flutter import). On the
/// web the Spoonacular API may be blocked by CORS, so we fall back to a proxy.
const bool _isWeb = identical(0, 0.0);
const String _corsProxy = 'https://api.allorigins.win/raw?url=';

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

/// Hand-tuned English search queries for the built-in seed recipes, so each
/// one matches a good Spoonacular photo (the auto keyword extraction otherwise
/// leaves German words in that return no result).
const Map<String, String> spoonacularQueryOverrides = {
  'seed-linsen-dal': 'red lentil dal',
  'seed-kichererbsen-curry': 'chickpea curry',
  'seed-haehnchen-bowl': 'chicken rice bowl',
  'seed-ofengemuese-feta': 'roasted vegetables feta',
  'seed-lachs-suesskartoffel': 'salmon sweet potato',
  'seed-pasta-spinat-ricotta': 'spinach ricotta pasta',
  'seed-chili-sin-carne': 'vegetarian chili beans',
  'seed-shakshuka': 'shakshuka',
  'seed-asia-nudeln-tofu': 'tofu noodle stir fry',
  'seed-kuerbissuppe': 'pumpkin soup',
  'seed-rindergeschnetzeltes': 'beef stroganoff',
  'seed-couscous-salat': 'couscous salad',
  'seed-gemuesepfanne-halloumi': 'halloumi vegetables',
  'seed-haehnchen-ofen-gemuese': 'sheet pan chicken vegetables',
  'seed-bowl-falafel': 'falafel bowl',
  'seed-spaghetti-bolognese-linsen': 'lentil bolognese spaghetti',
  'seed-gefuellte-suesskartoffel': 'stuffed sweet potato',
  'seed-omelett-gemuese': 'vegetable omelette',
  'seed-minestrone': 'minestrone soup',
  'seed-pute-wok-gruene-bohnen': 'turkey stir fry green beans',
  'seed-ofen-feta-pasta': 'baked feta pasta',
  'seed-rote-bete-salat': 'beetroot salad',
  'seed-gnocchi-mangold': 'gnocchi spinach',
};

/// The search query to use for a recipe: a hand-tuned override when available
/// (seed recipes), otherwise derived from its keywords.
String queryForRecipe(Recipe r) =>
    spoonacularQueryOverrides[r.id] ?? spoonacularQuery(r);

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
    res = await _getWithWebFallback(uri, c);
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

/// GETs [uri]. On the web, a direct call can be blocked by CORS (which surfaces
/// as a thrown "Failed to fetch"), so we retry once through a public CORS
/// proxy. On native platforms there is no CORS, so we only call directly.
Future<http.Response> _getWithWebFallback(Uri uri, http.Client c) async {
  try {
    return await c.get(uri).timeout(const Duration(seconds: 20));
  } catch (e) {
    if (!_isWeb) rethrow;
    final proxied =
        Uri.parse('$_corsProxy${Uri.encodeComponent(uri.toString())}');
    return c.get(proxied).timeout(const Duration(seconds: 30));
  }
}
