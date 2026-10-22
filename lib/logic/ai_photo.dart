import '../data/more_recipes.dart' show kMorePhotoQueries;
import '../models/recipe.dart';
import 'spoonacular.dart' show queryForRecipe;

/// Deterministic, high-quality AI food-photo URL for a recipe.
///
/// Uses Pollinations' Flux model — keyless, no quota — with a styled
/// "professional overhead food photography" prompt for a consistent, modern
/// recipe-app look. The URL is deterministic (stable seed per recipe), the
/// image is generated on first load and cached by URL, and it renders both in
/// the browser (via the `<img>` web path) and natively.
String aiPhotoUrl(Recipe r) {
  final subject = kMorePhotoQueries[r.id] ?? queryForRecipe(r);
  var seed = 0;
  for (final c in r.id.codeUnits) {
    seed = (seed * 31 + c) & 0x7fffffff;
  }
  seed %= 1000000;
  final prompt = '$subject, professional overhead food photography, '
      'plated on a ceramic dish on a light stone table, soft natural daylight, '
      'fresh herb garnish, beautifully styled, appetizing, shallow depth of '
      'field, high detail, no text';
  final enc = Uri.encodeComponent(prompt);
  return 'https://image.pollinations.ai/prompt/$enc'
      '?width=800&height=600&model=flux&nologo=true&seed=$seed';
}
