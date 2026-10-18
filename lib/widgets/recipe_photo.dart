import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme.dart';
import 'net_image.dart';

/// Shows a food photo for the recipe. Uses the recipe's own [Recipe.imageUrl]
/// when set (e.g. from an import), otherwise a keyless, direct image URL built
/// from the recipe's keywords — this loads as a plain image (no API key), so it
/// works both in the browser (via [netImage]'s web `<img>` path) and in the
/// native app. Falls back to a tasteful gradient + emoji when offline / on
/// error.
class RecipePhoto extends StatelessWidget {
  final Recipe recipe;
  final double? width;
  final double? height;
  final double radius;
  final double emojiSize;

  const RecipePhoto({
    super.key,
    required this.recipe,
    this.width,
    this.height,
    this.radius = 18,
    this.emojiSize = 34,
  });

  String get _url {
    if (recipe.imageUrl.isNotEmpty) return recipe.imageUrl;
    var lock = 0;
    for (final c in recipe.id.codeUnits) {
      lock = (lock * 31 + c) & 0x7fffffff;
    }
    lock = lock % 100000;
    // Keyless, always-returns-an-image food photo service. We derive a short
    // English food description from the recipe keywords and keep a stable seed
    // so each recipe always shows the same picture.
    final subject = recipe.photoKeywords.replaceAll(',', ' ').trim();
    final prompt = Uri.encodeComponent(
        '$subject, plated dish, food photography, overhead, natural light, '
        'appetizing, high detail');
    return 'https://image.pollinations.ai/prompt/$prompt'
        '?width=800&height=600&nologo=true&seed=$lock';
  }

  @override
  Widget build(BuildContext context) {
    return netImage(
      _url,
      width: width,
      height: height,
      radius: radius,
      placeholder: _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final base = AppColors.tileFor(recipe.title);
    final hsl = HSLColor.fromColor(base);
    final darker =
        hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, darker],
        ),
      ),
      alignment: Alignment.center,
      child: Text(recipe.emoji, style: TextStyle(fontSize: emojiSize)),
    );
  }
}
