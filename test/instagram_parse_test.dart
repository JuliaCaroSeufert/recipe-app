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

  test('enriches ingredients: servings, time, produce tags, nutrition, diet',
      () {
    const caption = '''
Buddha Bowl für 4 Portionen 🥗
Fertig in 20 Minuten

Zutaten:
- 400 g Kichererbsen (Dose)
- 2 Karotten
- 200 g Brokkoli
- 2 EL Olivenöl

Zubereitung:
1. Alles rösten.
2. Anrichten.
''';
    final recipe = parseInstagramCaption(caption);
    expect(recipe.baseServings, 4);
    expect(recipe.prepMinutes, 20);
    expect(recipe.produceKeys, containsAll(<String>{'Karotte', 'Brokkoli'}));
    expect(recipe.nutritionPerServing.kcal, greaterThan(0));
    expect(recipe.isVegan, isTrue);
    expect(recipe.title, 'Buddha Bowl');
  });

  test('parses unicode fractions in amounts', () {
    const caption = 'Zutaten:\n- ½ Zwiebel\n- 1½ EL Öl';
    final recipe = parseInstagramCaption(caption);
    expect(recipe.ingredients.first.amount, closeTo(0.5, 0.001));
    expect(recipe.ingredients[1].amount, closeTo(1.5, 0.001));
  });

  test('falls back gracefully without section headers', () {
    const caption = 'Omelett\nEier\nKäse\nAlles verquirlen und braten';
    final recipe = parseInstagramCaption(caption);
    expect(recipe.title, 'Omelett');
    expect(recipe.ingredients.isNotEmpty || recipe.steps.isNotEmpty, isTrue);
  });
}
