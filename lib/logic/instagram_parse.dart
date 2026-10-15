import 'package:uuid/uuid.dart';

import '../models/ingredient.dart';
import '../models/nutrition.dart';
import '../models/recipe.dart';

const _uuid = Uuid();

final RegExp _ingredientHeader =
    RegExp(r'^\s*(zutaten|ingredients|einkaufsliste)\b', caseSensitive: false);
final RegExp _stepsHeader = RegExp(
    r'^\s*(zubereitung|anleitung|so geht|method|instructions|steps|schritte)\b',
    caseSensitive: false);
final RegExp _bullet = RegExp(r'^\s*[-•*▪️·]\s+');
final RegExp _numberedStep = RegExp(r'^\s*\d+[\.\)]\s+');
final RegExp _leadingQuantity = RegExp(
    r'^\s*(\d+[.,]?\d*)\s*'
    r'(kg|g|ml|l|el|tl|stück|stk|dose|dosen|bund|prise|packung|pkg|tasse|tassen)?\b\s*(.*)$',
    caseSensitive: false);
final RegExp _hashtagOrMention = RegExp(r'^\s*[#@][^\s]+(\s+[#@][^\s]+)*\s*$');
final RegExp _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{FE0F}]',
    unicode: true);

String? _firstEmoji(String s) => _emoji.firstMatch(s)?.group(0);

String _removeEmoji(String s) =>
    s.replaceAll(_emoji, '').replaceAll(RegExp(r'\s+'), ' ').trim();

String _cleanLine(String line) => line.replaceAll('️', '').trim();

/// Best-effort parse of an Instagram caption into a draft recipe. Not perfect —
/// the user reviews and fixes everything in the edit screen afterwards.
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

  // Section-aware pass.
  var section = _Section.unknown;
  for (final line in lines) {
    if (_ingredientHeader.hasMatch(line)) {
      section = _Section.ingredients;
      continue;
    }
    if (_stepsHeader.hasMatch(line)) {
      section = _Section.steps;
      continue;
    }

    title ??= _stripTitle(line);

    if (section == _Section.ingredients) {
      ingredients.add(_parseIngredient(line));
    } else if (section == _Section.steps) {
      steps.add(_stripBullet(line));
    } else {
      // No headers seen yet: guess from the line shape.
      if (_numberedStep.hasMatch(line)) {
        steps.add(_stripBullet(line));
      } else if (_bullet.hasMatch(line) || _looksLikeIngredient(line)) {
        ingredients.add(_parseIngredient(line));
      } else if (title == _stripTitle(line)) {
        // first line used as title, skip
      } else {
        steps.add(line);
      }
    }
  }

  final detectedEmoji = _firstEmoji(title ?? '');
  final cleanTitle = _removeEmoji(title ?? '').trim();

  return Recipe(
    id: _uuid.v4(),
    title: cleanTitle.isEmpty ? 'Instagram-Rezept' : cleanTitle,
    emoji: detectedEmoji ?? '📸',
    description: url == null ? '' : 'Importiert von Instagram',
    ingredients: ingredients,
    steps: steps,
    tags: const ['instagram'],
    source: RecipeSource.instagram,
    sourceUrl: url,
    nutritionPerServing: Nutrition.zero,
    createdAt: DateTime.now(),
  );
}

enum _Section { unknown, ingredients, steps }

String _stripBullet(String line) =>
    line.replaceFirst(_bullet, '').replaceFirst(_numberedStep, '').trim();

String _stripTitle(String line) => line
    .replaceAll(RegExp(r'[#@][^\s]+'), '')
    .replaceFirst(_bullet, '')
    .trim();

bool _looksLikeIngredient(String line) {
  if (line.length > 60) return false;
  return _leadingQuantity.hasMatch(line) &&
      RegExp(r'\d').hasMatch(line.split(' ').first);
}

RecipeIngredient _parseIngredient(String raw) {
  final line = _stripBullet(raw);
  final m = _leadingQuantity.firstMatch(line);
  if (m != null && m.group(1) != null) {
    final amount = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
    final unit = _normalizeUnit(m.group(2));
    final name = (m.group(3) ?? '').trim();
    if (name.isNotEmpty) {
      return RecipeIngredient(name: name, amount: amount, unit: unit);
    }
  }
  return RecipeIngredient(name: line, amount: 0, unit: '');
}

String _normalizeUnit(String? u) {
  if (u == null) return '';
  switch (u.toLowerCase()) {
    case 'stk':
      return 'Stück';
    case 'dosen':
      return 'Dose';
    case 'pkg':
      return 'Packung';
    case 'tasse':
    case 'tassen':
      return 'Tasse';
    default:
      return u.toLowerCase() == 'el'
          ? 'EL'
          : u.toLowerCase() == 'tl'
              ? 'TL'
              : u.toLowerCase();
  }
}
