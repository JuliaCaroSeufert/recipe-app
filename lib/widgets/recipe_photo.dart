import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Shows a real food photo when the recipe has one (and lazily fetches it via
/// the photo service when a key is set), otherwise a tasteful gradient with the
/// recipe's emoji — so the app always looks intentional, online or offline.
class RecipePhoto extends StatefulWidget {
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
  State<RecipePhoto> createState() => _RecipePhotoState();
}

class _RecipePhotoState extends State<RecipePhoto> {
  @override
  void initState() {
    super.initState();
    _maybeFetch();
  }

  @override
  void didUpdateWidget(RecipePhoto old) {
    super.didUpdateWidget(old);
    if (old.recipe.id != widget.recipe.id) _maybeFetch();
  }

  void _maybeFetch() {
    if (widget.recipe.imageUrl.isEmpty) {
      // Fire-and-forget; AppState notifies when the photo arrives.
      context.read<AppState>().ensurePhotoFor(widget.recipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final child = r.imageUrl.isNotEmpty
        ? Image.network(
            r.imageUrl,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync || frame != null) return child;
              return _placeholder(context);
            },
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _placeholder(context),
            errorBuilder: (_, _, _) => _placeholder(context),
          )
        : _placeholder(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(width: widget.width, height: widget.height, child: child),
    );
  }

  Widget _placeholder(BuildContext context) {
    final base = AppColors.tileFor(widget.recipe.title);
    final hsl = HSLColor.fromColor(base);
    final darker =
        hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, darker],
        ),
      ),
      alignment: Alignment.center,
      child: Text(widget.recipe.emoji,
          style: TextStyle(fontSize: widget.emojiSize)),
    );
  }
}
