import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/plan_generator.dart';
import '../../models/recipe.dart';
import '../../models/week_plan.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/nutrient_dots.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/ui_kit.dart';

/// A card-by-card meal chooser (inspired by modern cooking apps): for each slot
/// it shows a big photo card with "Optionen" (next suggestion) and "Auswählen".
class MealPickerScreen extends StatefulWidget {
  /// Slots to fill, as (dayIndex, meal). If null, all empty slots are used.
  final List<(int, MealType)>? slots;
  const MealPickerScreen({super.key, this.slots});

  @override
  State<MealPickerScreen> createState() => _MealPickerScreenState();
}

class _MealPickerScreenState extends State<MealPickerScreen> {
  int _i = 0;
  int _cand = 0;

  List<(int, MealType)> _targetSlots(WeekPlan plan) {
    if (widget.slots != null) return widget.slots!;
    final out = <(int, MealType)>[];
    for (var d = 0; d < plan.days.length; d++) {
      for (final m in plan.days[d].meals.keys) {
        if (plan.days[d].slot(m).isEmpty) out.add((d, m));
      }
    }
    return out;
  }

  List<Recipe> _candidates(AppState app, WeekPlan plan, int day, MealType meal) {
    final base = filterForHousehold(app.recipes, app.household)
        .where((r) => r.suitableFor.contains(meal))
        .toList();
    // Prefer recipes not already used the same day.
    final usedToday = plan.days[day].meals.values
        .map((s) => s.recipeId)
        .whereType<String>()
        .toSet();
    base.sort((a, b) {
      final au = usedToday.contains(a.id) ? 1 : 0;
      final bu = usedToday.contains(b.id) ? 1 : 0;
      if (au != bu) return au - bu;
      return a.title.compareTo(b.title);
    });
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.currentPlan;
    if (plan == null) {
      return const Scaffold(body: Center(child: Text('Kein Plan.')));
    }
    final slots = _targetSlots(plan);

    if (_i >= slots.length) {
      return _DoneScreen(filled: slots.length);
    }

    final (day, meal) = slots[_i];
    final candidates = _candidates(app, plan, day, meal);
    final date = plan.days[day].date;

    if (candidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vorschläge')),
        body: const EmptyState(
          emoji: '🤔',
          title: 'Keine passenden Rezepte',
          message: 'Passe deine Filter/Abneigungen an oder füge Rezepte hinzu.',
        ),
      );
    }

    final recipe = candidates[_cand % candidates.length];
    final mealLabel = meal == MealType.lunch ? 'Mittagessen' : 'Abendessen';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context)),
        title: Text('${_i + 1} von ${slots.length}'),
        actions: [
          TextButton(
            onPressed: () => _skip(),
            child: const Text('Überspringen'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Icon(
                      meal == MealType.lunch
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_round,
                      size: 16,
                      color: meal == MealType.lunch
                          ? AppColors.amber
                          : AppColors.berry),
                  const SizedBox(width: 6),
                  Text('${weekdayName(date)} · $mealLabel',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _BigCard(recipe: recipe),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _cand = _cand + 1),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Anderer\nVorschlag',
                          textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _choose(app, day, meal, recipe),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Auswählen'),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _order(app, day, meal),
              icon: const Icon(Icons.delivery_dining_rounded, size: 18),
              label: const Text('Lieber bestellen'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(
      AppState app, int day, MealType meal, Recipe recipe) async {
    await app.updateSlot(
      day,
      meal,
      MealSlot(
          type: SlotType.cook,
          recipeId: recipe.id,
          servings: app.household.persons),
    );
    _advance();
  }

  Future<void> _order(AppState app, int day, MealType meal) async {
    await app.updateSlot(day, meal, const MealSlot(type: SlotType.order));
    _advance();
  }

  void _skip() => _advance();

  void _advance() => setState(() {
        _i += 1;
        _cand = 0;
      });
}

class _BigCard extends StatelessWidget {
  final Recipe recipe;
  const _BigCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RecipePhoto(
              recipe: recipe,
              width: double.infinity,
              radius: 0,
              emojiSize: 88,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                NutrientDots(recipe: recipe),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in recipe.highlights)
                      Pill(h,
                          color: AppColors.greenDeep,
                          background: const Color(0x1415B79E)),
                    Pill('${recipe.prepMinutes} Min',
                        icon: Icons.schedule_rounded),
                    Pill('${recipe.nutritionPerServing.kcal.round()} kcal',
                        icon: Icons.local_fire_department_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneScreen extends StatelessWidget {
  final int filled;
  const _DoneScreen({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        emoji: '🎉',
        title: 'Fertig zusammengestellt!',
        message: 'Deine Auswahl ist im Wochenplan gespeichert.',
        action: FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zum Plan'),
        ),
      ),
    );
  }
}
