import 'package:essensplan/logic/instagram_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a captioned recipe into title, ingredients and steps', () {
    const caption = '''
Schnelle Pasta Arrabbiata 🍝

Zutaten:
- 250 g Penne
- 2 Dose gehackte Tomaten
- 2 Knoblauch
- 1 TL Chiliflocken

Zubereitung:
1. Knoblauch anbraten.
2. Tomaten zugeben und köcheln.
3. Pasta untermischen.

#pasta #schnell @koch
''';
    final recipe = parseInstagramCaption(caption, url: 'https://insta/x');
    expect(recipe.title, 'Schnelle Pasta Arrabbiata');
    expect(recipe.ingredients.length, 4);
    expect(recipe.ingredients.first.name, 'Penne');
    expect(recipe.ingredients.first.amount, 250);
    expect(recipe.ingredients.first.unit, 'g');
    expect(recipe.steps.length, 3);
    expect(recipe.sourceUrl, 'https://insta/x');
    // Hashtag/mention line is dropped.
    expect(recipe.steps.any((s) => s.contains('#pasta')), isFalse);
  });

  test('falls back gracefully without section headers', () {
    const caption = 'Omelett\nEier\nKäse\nAlles verquirlen und braten';
    final recipe = parseInstagramCaption(caption);
    expect(recipe.title, 'Omelett');
    expect(recipe.ingredients.isNotEmpty || recipe.steps.isNotEmpty, isTrue);
  });
}
