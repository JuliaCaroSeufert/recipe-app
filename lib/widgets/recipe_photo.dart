import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme.dart';

/// Shows a food photo for the recipe. Uses the recipe's own [Recipe.imageUrl]
/// when set (e.g. from an import), otherwise a keyless, direct image URL
/// (LoremFlickr) built from the recipe's keywords — this loads as a plain
/// image, so it works in the browser and the app without any API call or key.
/// Falls back to a tasteful gradient + emoji when offline / on error.
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
    return 'https://loremflickr.com/600/400/${recipe.photoKeywords}?lock=$lock';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          _url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync || frame != null) return child;
            return _placeholder(context);
          },
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _placeholder(context),
          errorBuilder: (_, _, _) => _placeholder(context),
        ),
      ),
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
