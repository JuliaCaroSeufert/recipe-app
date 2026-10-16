import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/recipe.dart';

const _uuid = Uuid();

/// Default free Gemini Flash model. Google rotates these; if it 404s with
/// "no longer available", the code reads the suggested model and retries.
const String _defaultModel = 'gemini-3.8-flash';

const _categories = [
  'produce', 'legumes', 'dairy', 'meatFish', 'pantry', 'spices', 'frozen', 'other',
];
const _units = [
  '', 'g', 'ml', 'Stück', 'EL', 'TL', 'Prise', 'Dose', 'Bund', 'Packung', 'Tasse',
];
const _nutrientKeys = [
  'kcal', 'protein', 'carbs', 'fat', 'fiber', 'iron', 'calcium', 'magnesium',
  'potassium', 'zinc', 'vitaminC', 'vitaminA', 'folate',
];

const _systemPrompt = '''
Du bist ein Ernährungs- und Rezept-Assistent für die App "Essensplan".
Du bekommst den Beschreibungstext (Caption) eines Koch-Reels/-Posts und baust
daraus EIN strukturiertes Rezept.

Regeln:
- Alle für Nutzer sichtbaren Texte auf DEUTSCH (Titel, Zutaten, Schritte).
- Mengen beziehen sich auf baseServings Portionen. Erkenne Portionen und
  Zubereitungszeit aus dem Text; wenn unklar: baseServings=2, prepMinutes=30.
- Zutaten-Kategorie aus der erlaubten Liste wählen. Für Gemüse UND
  Hülsenfrüchte setze produceKey auf den kanonischen Namen (z. B. "Karotte",
  "Kichererbse", "Spinat"); bei allem anderen produceKey=null. Alltags-Stärke
  wie Kartoffel/Reis/Nudeln ist KEIN produceKey.
- Schätze die Nährwerte PRO PORTION so gut es geht (Makros + Mikros) aus den
  Zutaten und Mengen. Lieber eine fundierte Schätzung als Nullen.
- isVegan/isVegetarian aus den Zutaten ableiten. batchFriendly=true NUR wenn
  sich das Gericht gekocht 4–5 Tage im Kühlschrank hält und gut aufwärmbar ist
  (Eintöpfe, Currys, Dal, Suppen, Chili, Bolognese/Tomatensaucen, Aufläufe).
  Frische Bowls, Salate, Ofengemüse und knusprige Gerichte = false.
- Wähle ein passendes Emoji. Erfinde keine Schritte, die nicht im Text stehen.
''';

String _shapeHint() =>
    'Antworte AUSSCHLIESSLICH mit einem JSON-Objekt (kein Text, kein Markdown) '
    'mit genau diesen Feldern: title (string), emoji (string), '
    'description (string), prepMinutes (integer), baseServings (integer), '
    "suitableFor (Array aus 'lunch'/'dinner'), tags (Array strings), "
    'isVegetarian (bool), isVegan (bool), batchFriendly (bool), ingredients '
    '(Array von {name (string), amount (number), unit (einer von $_units), '
    'category (einer von $_categories), produceKey (string oder null)}), '
    'steps (Array strings), nutritionPerServing (Objekt mit genau diesen '
    'Zahlenfeldern: $_nutrientKeys). Keine zusätzlichen Felder.';

/// Thrown for a user-friendly error message in the UI.
class AiImportException implements Exception {
  final String message;
  AiImportException(this.message);
  @override
  String toString() => message;
}

/// Calls Google Gemini to turn [caption] into a [Recipe]. [apiKey] is the
/// user's free AI-Studio key. Throws [AiImportException] with a readable
/// message on failure.
Future<Recipe> aiExtractRecipe(
  String caption, {
  required String apiKey,
  String? url,
}) async {
  if (apiKey.trim().isEmpty) {
    throw AiImportException('Kein Gemini-Schlüssel hinterlegt.');
  }
  final userText = url == null ? caption : 'Quelle: $url\n\n$caption';

  var model = _defaultModel;
  for (var attempt = 0; attempt < 2; attempt++) {
    final res = await _callGemini(model, apiKey, userText);
    if (res.ok) {
      return _toRecipe(res.json!, url);
    }
    // If the model was retired, Google names the replacement — retry once.
    final suggested = _suggestedModel(res.error ?? '');
    if (suggested != null && suggested != model) {
      model = suggested;
      continue;
    }
    throw AiImportException(_friendly(res.statusCode, res.error ?? ''));
  }
  throw AiImportException('KI-Import fehlgeschlagen.');
}

class _GeminiResult {
  final bool ok;
  final Map<String, dynamic>? json;
  final int statusCode;
  final String? error;
  _GeminiResult(this.ok, this.json, this.statusCode, this.error);
}

Future<_GeminiResult> _callGemini(
    String model, String apiKey, String userText) async {
  final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
  final body = jsonEncode({
    'systemInstruction': {
      'parts': [
        {'text': '$_systemPrompt\n\n${_shapeHint()}'}
      ]
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': userText}
        ]
      }
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'temperature': 0.2,
    },
  });

  http.Response res;
  try {
    res = await http
        .post(uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: body)
        .timeout(const Duration(seconds: 45));
  } catch (e) {
    return _GeminiResult(false, null, 0, 'Netzwerkfehler: $e');
  }

  if (res.statusCode != 200) {
    return _GeminiResult(false, null, res.statusCode, res.body);
  }
  try {
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final text = (((decoded['candidates'] as List?)?.first
            as Map?)?['content'] as Map?)?['parts'] as List?;
    final raw = (text?.first as Map?)?['text'] as String?;
    if (raw == null) {
      return _GeminiResult(false, null, 200, 'Leere Antwort vom Modell.');
    }
    final recipeJson =
        jsonDecode(_stripFence(raw)) as Map<String, dynamic>;
    return _GeminiResult(true, recipeJson, 200, null);
  } catch (e) {
    return _GeminiResult(false, null, 200, 'Antwort nicht lesbar: $e');
  }
}

String _stripFence(String text) {
  var t = text.trim();
  if (t.startsWith('```')) {
    final nl = t.indexOf('\n');
    if (nl >= 0) t = t.substring(nl + 1);
    if (t.endsWith('```')) t = t.substring(0, t.length - 3);
  }
  return t.trim();
}

String? _suggestedModel(String errorBody) {
  final m = RegExp(r'models/([a-z0-9.\-]*flash[a-z0-9.\-]*)')
      .firstMatch(errorBody);
  return m?.group(1);
}

String _friendly(int status, String body) {
  if (status == 400 && body.contains('API_KEY_INVALID')) {
    return 'Gemini-Schlüssel ungültig. Prüfe ihn in den Einstellungen.';
  }
  if (status == 429) {
    return 'Gemini-Limit erreicht (Gratis-Stufe). Später nochmal versuchen.';
  }
  if (status == 0) return body;
  return 'KI-Import fehlgeschlagen (Code $status).';
}

/// Merges the AI JSON with generated id/date/source, then reuses
/// [Recipe.fromJson] so categories, nutrition and meal types parse as usual.
Recipe _toRecipe(Map<String, dynamic> json, String? url) {
  // Keep only known categories/units safe; Recipe.fromJson tolerates the rest.
  final merged = <String, dynamic>{
    ...json,
    'id': _uuid.v4(),
    'createdAt': DateTime.now().toIso8601String(),
    'source': 'instagram',
    'sourceUrl': ?url,
  };
  final recipe = Recipe.fromJson(merged);
  // Make sure at least the "instagram" tag is present for consistency.
  final tags = {...recipe.tags, 'instagram'}.toList();
  // Drop ingredients that ended up without a usable name.
  final cleaned = recipe.ingredients
      .where((i) => i.name.trim().isNotEmpty)
      .toList();
  return recipe.copyWith(tags: tags, ingredients: cleaned);
}
