import 'package:flutter/material.dart';

import '../data/photo_store.dart';
import '../models/recipe.dart';
import '../theme.dart';
import 'net_image.dart';

/// Shows a food photo for the recipe. Seed recipes use a bundled asset; other
/// recipes (imports) use their photo URL, cached to device bytes after the
/// first load (via [PhotoStore]) so it then loads offline. When no photo
/// is set yet it falls back to a tasteful gradient + emoji tile.
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

  @override
  Widget build(BuildContext context) {
    final url = recipe.imageUrl;
    // Bundled AI photo asset (the common case for seed recipes).
    if (url.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(
            url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(context),
          ),
        ),
      );
    }
    // Imported recipes carry a photo URL. Prefer bytes already saved on the
    // device (offline, instant); otherwise show the network image and save it
    // for next time.
    if (url.isNotEmpty) {
      final cached = PhotoStore.bytes(recipe.id);
      if (cached != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: width,
            height: height,
            child: Image.memory(
              cached,
              width: width,
              height: height,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _placeholder(context),
            ),
          ),
        );
      }
      PhotoStore.cacheFromUrl(recipe.id, url);
      return netImage(
        url,
        width: width,
        height: height,
        radius: radius,
        placeholder: _placeholder(context),
      );
    }
    // No photo yet → the tasteful gradient + emoji tile.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: _placeholder(context),
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
