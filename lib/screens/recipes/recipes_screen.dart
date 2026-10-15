import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../state/app_state.dart';
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
            icon: const Icon(Icons.add),
            onSelected: (value) {
              if (value == 'manual') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecipeEditScreen()),
                );
              } else if (value == 'instagram') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const InstagramImportScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'manual',
                child: ListTile(
                  leading: Icon(Icons.edit_note),
                  title: Text('Eigenes Rezept'),
                ),
              ),
              PopupMenuItem(
                value: 'instagram',
                child: ListTile(
                  leading: Icon(Icons.photo_camera_back_outlined),
                  title: Text('Aus Instagram importieren'),
                ),
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
        title: Text(meal == null
            ? 'Rezept wählen'
            : 'Rezept für ${meal!.label}'),
      ),
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
    'schnell': 'Schnell',
    'vegetarisch': 'Vegetarisch',
    'vegan': 'Vegan',
    'batch': 'Batch',
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
      ..sort((a, b) => a.title.compareTo(b.title));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rezept oder Zutat suchen',
              prefixIcon: Icon(Icons.search),
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
              ? const Center(child: Text('Keine Rezepte gefunden.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: recipes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => RecipeTile(
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

class RecipeTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeTile({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(recipe.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${recipe.prepMinutes} Min',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 10),
                        Icon(Icons.local_fire_department,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${recipe.nutritionPerServing.kcal.round()} kcal',
                            style: Theme.of(context).textTheme.bodySmall),
                        if (recipe.isVegan) ...[
                          const SizedBox(width: 8),
                          const Text('🌱', style: TextStyle(fontSize: 12)),
                        ] else if (recipe.isVegetarian) ...[
                          const SizedBox(width: 8),
                          const Text('🥕', style: TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (recipe.batchFriendly)
                Tooltip(
                  message: 'Gut zum Vorkochen',
                  child: Icon(Icons.inventory_2_outlined,
                      size: 18, color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
