import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../models/week_plan.dart';
import '../../state/app_state.dart';
import '../../utils/dates.dart';
import '../../widgets/nutrition_widgets.dart';
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
      return const Scaffold(
        body: Center(child: Text('Rezept nicht gefunden.')),
      );
    }
    final servings = _servings ?? app.household.persons;
    final factor = recipe.baseServings == 0
        ? 1.0
        : servings / recipe.baseServings;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RecipeEditScreen(existing: recipe)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Löschen',
            onPressed: () => _confirmDelete(context, app, recipe),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Row(
            children: [
              Text(recipe.emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${recipe.prepMinutes} Min · '
                        '${recipe.nutritionPerServing.kcal.round()} kcal/Portion'),
                    if (recipe.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(recipe.description,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in recipe.tags) Chip(label: Text(t)),
            ],
          ),
          const SizedBox(height: 16),

          // Servings stepper
          Row(
            children: [
              Text('Portionen', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: servings > 1
                    ? () => setState(() => _servings = servings - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$servings',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => _servings = servings + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const Divider(height: 28),

          Text('Zutaten', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final ing in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Text('• '),
                  Expanded(child: Text(ing.name)),
                  Text(_amountLabel(ing.amount * factor, ing.unit),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                ],
              ),
            ),

          const Divider(height: 28),
          Text('Zubereitung', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < recipe.steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(recipe.steps[i])),
                ],
              ),
            ),

          const Divider(height: 28),
          Text('Nährwerte pro Portion',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Balken = Anteil am Tagesbedarf einer Person',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          NutrientBars(values: recipe.nutritionPerServing),

          if (recipe.sourceUrl != null) ...[
            const SizedBox(height: 16),
            Text('Quelle: ${recipe.sourceUrl}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addToPlan(context, app, recipe, servings),
        icon: const Icon(Icons.calendar_month),
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
      BuildContext context, AppState app, Recipe recipe, int servings) async {
    final plan = app.currentPlan;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Plane zuerst eine Woche im Tab "Woche".')),
      );
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
        servings: app.household.persons,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${recipe.title}" eingeplant.')),
      );
    }
  }
}

String _amountLabel(double amount, String unit) {
  if (amount <= 0) return '';
  final text = amount == amount.roundToDouble()
      ? amount.round().toString()
      : amount.toStringAsFixed(1);
  return unit.isEmpty ? text : '$text $unit';
}
