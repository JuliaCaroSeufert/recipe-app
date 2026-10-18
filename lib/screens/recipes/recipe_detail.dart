import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../models/week_plan.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/nutrition_widgets.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/ui_kit.dart';
import 'recipe_edit.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  int? _servings;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recipe = app.recipeById(widget.recipeId);
    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('Rezept nicht gefunden.')));
    }
    final scheme = Theme.of(context).colorScheme;
    final servings = _servings ?? app.household.persons;
    final factor =
        recipe.baseServings == 0 ? 1.0 : servings / recipe.baseServings;
    final n = recipe.nutritionPerServing;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: AppColors.tileFor(recipe.title),
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              _RoundIcon(
                icon: Icons.edit_outlined,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => RecipeEditScreen(existing: recipe))),
              ),
              _RoundIcon(
                icon: Icons.delete_outline_rounded,
                onTap: () => _confirmDelete(context, app, recipe),
              ),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  RecipePhoto(recipe: recipe, radius: 0, emojiSize: 84),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x55000000), Color(0x00000000),
                          Color(0x00000000)],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(recipe.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Pill('${recipe.prepMinutes} Min',
                          icon: Icons.schedule_rounded),
                      Pill('${n.kcal.round()} kcal',
                          icon: Icons.local_fire_department_rounded),
                      if (recipe.isVegan)
                        const Pill('vegan',
                            background: Color(0x1A1E9E63),
                            color: AppColors.greenDeep)
                      else if (recipe.isVegetarian)
                        const Pill('vegetarisch'),
                      if (recipe.batchFriendly)
                        const Pill('gut vorzukochen',
                            icon: Icons.inventory_2_outlined),
                    ],
                  ),

                  const SizedBox(height: 20),
                  // Quick nutrition rings (per serving vs daily need).
                  SoftCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ProgressRing(
                            value: n.kcal / 2000,
                            color: AppColors.amber,
                            centerText: '${n.kcal.round()}',
                            label: 'kcal'),
                        ProgressRing(
                            value: n.protein / 60,
                            color: AppColors.green,
                            centerText: '${n.protein.round()}g',
                            label: 'Eiweiß'),
                        ProgressRing(
                            value: n.fiber / 30,
                            color: AppColors.berry,
                            centerText: '${n.fiber.round()}g',
                            label: 'Ballast.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Servings stepper.
                  Row(
                    children: [
                      Text('Portionen',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: servings > 1
                            ? () => setState(() => _servings = servings - 1)
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('$servings',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => setState(() => _servings = servings + 1),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text('Zutaten',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final ing in recipe.ingredients)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(
                            ing.countsAsVariety
                                ? Icons.eco_rounded
                                : Icons.circle,
                            size: ing.countsAsVariety ? 16 : 7,
                            color: ing.countsAsVariety
                                ? AppColors.green
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(ing.name)),
                          Text(_amount(ing.amount * factor, ing.unit),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  Text('Zubereitung',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (var i = 0; i < recipe.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text('${i + 1}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: AppColors.greenDeep)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(recipe.steps[i]),
                          )),
                        ],
                      ),
                    ),

                  const SizedBox(height: 18),
                  Text('Nährwerte pro Portion',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  NutrientBars(values: n),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addToPlan(context, app, recipe),
        icon: const Icon(Icons.calendar_month_rounded),
        label: const Text('Zum Plan'),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState app, Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rezept löschen?'),
        content: Text('"${recipe.title}" wird aus deiner Sammlung entfernt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await app.deleteRecipe(recipe.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _addToPlan(
      BuildContext context, AppState app, Recipe recipe) async {
    final plan = app.currentPlan;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plane zuerst eine Woche im Tab "Woche".')));
      return;
    }
    final choice = await showModalBottomSheet<(int, MealType)>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (var d = 0; d < plan.days.length; d++)
            for (final meal in plan.days[d].meals.keys)
              ListTile(
                title: Text(
                    '${weekdayName(plan.days[d].date)} · ${meal.shortLabel}'),
                subtitle: Text(dayMonth(plan.days[d].date)),
                onTap: () => Navigator.pop(context, (d, meal)),
              ),
        ],
      ),
    );
    if (choice == null) return;
    await app.updateSlot(
      choice.$1,
      choice.$2,
      MealSlot(
          type: SlotType.cook,
          recipeId: recipe.id,
          servings: app.household.persons),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${recipe.title}" eingeplant.')));
    }
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

String _amount(double amount, String unit) {
  if (amount <= 0) return '';
  final text = amount == amount.roundToDouble()
      ? amount.round().toString()
      : amount.toStringAsFixed(1);
  return unit.isEmpty ? text : '$text $unit';
}
