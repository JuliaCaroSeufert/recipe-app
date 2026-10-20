import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../widgets/nutrient_dots.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/ui_kit.dart';
import 'instagram_import.dart';
import 'recipe_detail.dart';
import 'recipe_edit.dart';

/// Browse/search the recipe library (bottom-tab screen).
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezepte'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onSelected: (value) {
              if (value == 'manual') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RecipeEditScreen()));
              } else if (value == 'paste') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const InstagramImportScreen(generic: true)));
              } else if (value == 'instagram') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InstagramImportScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'manual',
                child: ListTile(
                    leading: Icon(Icons.edit_note_rounded),
                    title: Text('Eigenes Rezept')),
              ),
              PopupMenuItem(
                value: 'paste',
                child: ListTile(
                    leading: Icon(Icons.content_paste_rounded),
                    title: Text('Rezept einfügen (Text)')),
              ),
              PopupMenuItem(
                value: 'instagram',
                child: ListTile(
                    leading: Icon(Icons.auto_awesome_rounded),
                    title: Text('Aus Instagram importieren')),
              ),
            ],
          ),
        ],
      ),
      body: const RecipeListView(),
    );
  }
}

/// Standalone picker that returns the chosen [Recipe].
class RecipePickerScreen extends StatelessWidget {
  final MealType? meal;
  const RecipePickerScreen({super.key, this.meal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              meal == null ? 'Rezept wählen' : 'Rezept für ${meal!.label}')),
      body: RecipeListView(
        restrictMeal: meal,
        onTap: (recipe) => Navigator.pop(context, recipe),
      ),
    );
  }
}

/// Shared searchable, filterable recipe list.
class RecipeListView extends StatefulWidget {
  final void Function(Recipe recipe)? onTap;
  final MealType? restrictMeal;

  const RecipeListView({super.key, this.onTap, this.restrictMeal});

  @override
  State<RecipeListView> createState() => _RecipeListViewState();
}

class _RecipeListViewState extends State<RecipeListView> {
  String _query = '';
  final Set<String> _filters = {};

  static const _chips = {
    'favoriten': 'Favoriten',
    'schnell': 'Schnell',
    'vegetarisch': 'Vegetarisch',
    'vegan': 'Vegan',
    'batch': 'Vorkochen',
  };

  bool _matches(Recipe r) {
    if (widget.restrictMeal != null &&
        !r.suitableFor.contains(widget.restrictMeal)) {
      return false;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final hit = r.title.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q)) ||
          r.ingredients.any((i) => i.name.toLowerCase().contains(q));
      if (!hit) return false;
    }
    for (final f in _filters) {
      switch (f) {
        case 'favoriten':
          if (!r.isFavorite) return false;
        case 'schnell':
          if (!r.isQuick) return false;
        case 'vegetarisch':
          if (!r.isVegetarian) return false;
        case 'vegan':
          if (!r.isVegan) return false;
        case 'batch':
          if (!r.batchFriendly) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recipes = app.recipes.where(_matches).toList()
      // Favourites first, then alphabetical.
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.title.compareTo(b.title);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rezept oder Zutat suchen',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final entry in _chips.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: _filters.contains(entry.key),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _filters.add(entry.key);
                      } else {
                        _filters.remove(entry.key);
                      }
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: recipes.isEmpty
              ? const EmptyState(
                  emoji: '🔍',
                  title: 'Nichts gefunden',
                  message: 'Ändere die Suche oder die Filter.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: recipes.length,
                  itemBuilder: (context, i) => RecipeCard(
                    recipe: recipes[i],
                    onTap: () {
                      if (widget.onTap != null) {
                        widget.onTap!(recipes[i]);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RecipeDetailScreen(recipeId: recipes[i].id),
                          ),
                        );
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Small circular heart button overlaid on a recipe photo to toggle favourite.
class _HeartButton extends StatelessWidget {
  final Recipe recipe;
  const _HeartButton({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final fav = recipe.isFavorite;
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.read<AppState>().toggleFavorite(recipe.id),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 18,
            color: fav
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A photo-forward tile for the 2-column recipe grid (inspired by modern
/// cooking apps): big photo on top, title + nutrient dots + quick meta below.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onVar = Theme.of(context).colorScheme.onSurfaceVariant;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.25,
                child: RecipePhoto(recipe: recipe, radius: 16, emojiSize: 46),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _HeartButton(recipe: recipe),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(height: 1.1)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: NutrientDots(recipe: recipe, max: 2),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: onVar),
                const SizedBox(width: 4),
                Text('${recipe.prepMinutes} Min',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 10),
                Icon(Icons.local_fire_department_rounded, size: 14, color: onVar),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('${recipe.nutritionPerServing.kcal.round()} kcal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
