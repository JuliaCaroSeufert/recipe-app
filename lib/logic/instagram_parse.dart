import 'package:uuid/uuid.dart';

import '../data/food_db.dart';
import '../models/ingredient.dart';
import '../models/nutrition.dart';
import '../models/recipe.dart';

const _uuid = Uuid();

final RegExp _ingredientHeader = RegExp(
    r'^\s*(zutaten|ingredients|einkaufsliste|du brauchst|das brauchst du)\b',
    caseSensitive: false);
final RegExp _stepsHeader = RegExp(
    r'^\s*(zubereitung|anleitung|so geht|so wird|method|instructions|steps|schritte|und so)\b',
    caseSensitive: false);
final RegExp _bullet = RegExp(r'^\s*[-•*▪️·✔️☑️➡️▸‣]\s*');
final RegExp _numberedStep = RegExp(r'^\s*\d+[\.\)]\s+');
final RegExp _leadingQuantity = RegExp(
    r'^\s*(\d+[.,]?\d*)\s*'
    r'(kg|g|gramm|ml|l|liter|el|essl\.?|tl|teel\.?|stück|stk|dose|dosen|bund|'
    r'prise|packung|pkg|tasse|tassen|zehen|zehe)?\b\.?\s*(.*)$',
    caseSensitive: false);
final RegExp _hashtagOrMention = RegExp(r'^\s*[#@][^\s]+(\s+[#@][^\s]+)*\s*$');
final RegExp _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{FE0F}]',
    unicode: true);
final RegExp _servingsRe = RegExp(
    r'(?:für\s+)?(\d+)\s*(?:portionen|portion|personen|person|servings|serves)\b',
    caseSensitive: false);
final RegExp _timeRe =
    RegExp(r'(\d+)\s*(?:min|minuten|minute)\b', caseSensitive: false);

const Map<String, String> _fractions = {
  '½': '.5',
  '¼': '.25',
  '¾': '.75',
  '⅓': '.33',
  '⅔': '.67',
  '⅛': '.125',
};

String? _firstEmoji(String s) => _emoji.firstMatch(s)?.group(0);

String _removeEmoji(String s) =>
    s.replaceAll(_emoji, '').replaceAll(RegExp(r'\s+'), ' ').trim();

String _cleanLine(String line) => line.replaceAll('️', '').trim();

String _preprocessNumbers(String line) {
  var s = line;
  _fractions.forEach((frac, dec) {
    s = s.replaceAllMapped(RegExp('(\\d)\\s*$frac'), (m) => '${m[1]}$dec');
    s = s.replaceAll(frac, '0$dec');
  });
  return s;
}

/// Best-effort parse of an Instagram caption into a draft recipe. The food
/// database fills in categories, vegetable tags and an estimated nutrition so
/// the imported recipe behaves like the built-in ones. The user reviews
/// everything afterwards.
Recipe parseInstagramCaption(String caption, {String? url}) {
  final rawLines = caption.split('\n');
  final lines = <String>[];
  for (final l in rawLines) {
    final c = _cleanLine(l);
    if (c.isEmpty) continue;
    if (_hashtagOrMention.hasMatch(c)) continue;
    lines.add(c);
  }

  final ingredients = <RecipeIngredient>[];
  final steps = <String>[];
  String? title;
  int? servings;
  int? prepMinutes;

  var section = _Section.unknown;
  for (final line in lines) {
    servings ??= _matchInt(_servingsRe, line);
    prepMinutes ??= _matchInt(_timeRe, line);

    if (_ingredientHeader.hasMatch(line)) {
      section = _Section.ingredients;
      continue;
    }
    if (_stepsHeader.hasMatch(line)) {
      section = _Section.steps;
      continue;
    }

    title ??= _stripTitle(line);

    if (_isMetaLine(line)) continue;

    if (section == _Section.ingredients) {
      ingredients.add(_parseIngredient(line));
    } else if (section == _Section.steps) {
      steps.add(_stripBullet(line));
    } else {
      if (_numberedStep.hasMatch(line)) {
        steps.add(_stripBullet(line));
      } else if (_bullet.hasMatch(line) || _looksLikeIngredient(line)) {
        ingredients.add(_parseIngredient(line));
      } else if (title == _stripTitle(line)) {
        // first line already used as title
      } else {
        steps.add(line);
      }
    }
  }

  final baseServings = (servings != null && servings > 0) ? servings : 2;
  final nutrition = estimateNutritionPerServing(ingredients, baseServings);
  final diet = _inferDiet(ingredients);

  final detectedEmoji = _firstEmoji(title ?? '');
  final cleanTitle = _removeEmoji(title ?? '').trim();

  final tags = <String>['instagram'];
  if (prepMinutes != null && prepMinutes <= 30) tags.add('schnell');
  if (diet.vegan) {
    tags.add('vegan');
  } else if (diet.vegetarian) {
    tags.add('vegetarisch');
  }

  return Recipe(
    id: _uuid.v4(),
    title: cleanTitle.isEmpty ? 'Instagram-Rezept' : cleanTitle,
    emoji: detectedEmoji ?? '📸',
    description: 'Aus Instagram importiert',
    prepMinutes: prepMinutes ?? 30,
    baseServings: baseServings,
    ingredients: ingredients,
    steps: steps,
    tags: tags,
    isVegetarian: diet.vegetarian,
    isVegan: diet.vegan,
    source: RecipeSource.instagram,
    sourceUrl: url,
    nutritionPerServing: nutrition,
    createdAt: DateTime.now(),
  );
}

/// Sums the nutrition of known ingredients and divides by [servings].
Nutrition estimateNutritionPerServing(
    List<RecipeIngredient> ingredients, int servings) {
  var total = Nutrition.zero;
  for (final ing in ingredients) {
    final entry = lookupFood(ing.name);
    if (entry == null) continue;
    final grams = gramsOf(ing.amount, ing.unit, entry);
    if (grams <= 0) continue;
    total = total + entry.per100g.scale(grams / 100);
  }
  if (servings <= 0) return total;
  return total.scale(1 / servings);
}

class _Diet {
  final bool vegetarian;
  final bool vegan;
  const _Diet(this.vegetarian, this.vegan);
}

_Diet _inferDiet(List<RecipeIngredient> ingredients) {
  var matched = 0;
  var hasMeat = false;
  var hasDairyEgg = false;
  for (final ing in ingredients) {
    final entry = lookupFood(ing.name);
    if (entry == null) continue;
    matched++;
    if (entry.kind == FoodKind.meatFish) hasMeat = true;
    if (entry.kind == FoodKind.dairyEgg) hasDairyEgg = true;
  }
  if (matched == 0) return const _Diet(false, false);
  final vegetarian = !hasMeat;
  final vegan = vegetarian && !hasDairyEgg;
  return _Diet(vegetarian, vegan);
}

int? _matchInt(RegExp re, String line) {
  final m = re.firstMatch(line);
  if (m == null) return null;
  return int.tryParse(m.group(1) ?? '');
}

enum _Section { unknown, ingredients, steps }

String _stripBullet(String line) =>
    line.replaceFirst(_bullet, '').replaceFirst(_numberedStep, '').trim();

String _stripTitle(String line) => line
    .replaceAll(RegExp(r'[#@][^\s]+'), '')
    .replaceFirst(_bullet, '')
    .replaceFirst(
        RegExp(r'^\s*(rezept|recipe)\s*[:\-]\s*', caseSensitive: false), '')
    .replaceAll(_servingsRe, '')
    .replaceAll(
        RegExp(r'(fertig\s+in\s+)?\d+\s*(min|minuten|minute)\b',
            caseSensitive: false),
        '')
    .replaceAll(RegExp(r'\s*[·\-–|]\s*$'), '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

/// True for lines that only state servings or time (and no food) — these are
/// captured into fields, not kept as steps.
bool _isMetaLine(String line) {
  final hasMeta = _servingsRe.hasMatch(line) || _timeRe.hasMatch(line);
  if (!hasMeta) return false;
  final words = line.trim().split(RegExp(r'\s+')).length;
  return words <= 4 && lookupFood(line) == null;
}

bool _looksLikeIngredient(String line) {
  if (line.length > 70) return false;
  final pre = _preprocessNumbers(line);
  return _leadingQuantity.hasMatch(pre) && RegExp(r'^\s*\d').hasMatch(pre);
}

RecipeIngredient _parseIngredient(String raw) {
  final line = _preprocessNumbers(_stripBullet(raw));
  final m = _leadingQuantity.firstMatch(line);
  String name;
  double amount = 0;
  String unit = '';
  if (m != null && m.group(1) != null) {
    amount = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
    unit = _normalizeUnit(m.group(2));
    name = (m.group(3) ?? '').trim();
    if (name.isEmpty) name = line.trim();
  } else {
    name = line.trim();
  }

  // Enrich from the food database.
  final entry = lookupFood(name);
  return RecipeIngredient(
    name: name,
    amount: amount,
    unit: unit,
    category: entry?.category ?? IngredientCategory.other,
    produceKey: entry?.produceKey,
  );
}

String _normalizeUnit(String? u) {
  if (u == null) return '';
  switch (u.toLowerCase()) {
    case 'g':
    case 'gramm':
      return 'g';
    case 'l':
    case 'liter':
      return 'l';
    case 'stk':
    case 'stück':
      return 'Stück';
    case 'zehe':
    case 'zehen':
      return 'Stück';
    case 'dose':
    case 'dosen':
      return 'Dose';
    case 'pkg':
    case 'packung':
      return 'Packung';
    case 'tasse':
    case 'tassen':
      return 'Tasse';
    case 'el':
    case 'essl':
    case 'essl.':
      return 'EL';
    case 'tl':
    case 'teel':
    case 'teel.':
      return 'TL';
    default:
      return u.toLowerCase();
  }
}
