import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../models/week_plan.dart';
import '../../state/app_state.dart';
import '../../utils/dates.dart';
import '../../widgets/nutrition_widgets.dart';
import '../archive/archive_screen.dart';
import '../recipes/recipe_detail.dart';
import '../recipes/recipes_screen.dart';
import 'generate_screen.dart';
import 'nutrition_screen.dart';

class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.currentPlan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Wochenplan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Archiv & Recycling',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArchiveScreen())),
          ),
        ],
      ),
      body: plan == null
          ? _EmptyWeek()
          : _PlanView(plan: plan),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GenerateScreen())),
        icon: const Icon(Icons.auto_awesome),
        label: Text(plan == null ? 'Woche planen' : 'Neu planen'),
      ),
    );
  }
}

class _EmptyWeek extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥗', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('Noch kein Plan',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Lass dir eine ausgewogene Woche mit Mittag- und Abendessen '
              'vorschlagen – mit Batch-Cooking, Bestell-Tagen und viel Gemüse.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanView extends StatelessWidget {
  final WeekPlan plan;
  const _PlanView({required this.plan});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final analysis = app.currentAnalysis!;
    final ppd = analysis.perPersonPerDay;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            weekRangeLabel(plan.startDate, plan.days.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                VarietyProgress(
                  count: analysis.varietyCount,
                  target: analysis.varietyTarget,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.local_fire_department,
                        value: '${ppd.kcal.round()}',
                        label: 'kcal / Tag',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        icon: Icons.egg_alt_outlined,
                        value: '${ppd.protein.round()} g',
                        label: 'Eiweiß / Tag',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        icon: Icons.grass,
                        value: '${ppd.fiber.round()} g',
                        label: 'Ballast. / Tag',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NutritionScreen())),
                    icon: const Icon(Icons.insights, size: 18),
                    label: const Text('Alle Nährwerte'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var d = 0; d < plan.days.length; d++)
          _DayCard(plan: plan, dayIndex: d),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final WeekPlan plan;
  final int dayIndex;
  const _DayCard({required this.plan, required this.dayIndex});

  @override
  Widget build(BuildContext context) {
    final day = plan.days[dayIndex];
    final meals = day.meals.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Text(
                '${weekdayName(day.date)}, ${dayMonth(day.date)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final meal in meals)
              _SlotRow(
                plan: plan,
                dayIndex: dayIndex,
                meal: meal,
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final WeekPlan plan;
  final int dayIndex;
  final MealType meal;

  const _SlotRow({
    required this.plan,
    required this.dayIndex,
    required this.meal,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final slot = plan.days[dayIndex].slot(meal);
    final recipe = app.recipeById(slot.recipeId);
    final scheme = Theme.of(context).colorScheme;

    String leading;
    String titleText;
    String? subtitle;

    switch (slot.type) {
      case SlotType.cook:
        leading = recipe?.emoji ?? '🍽️';
        titleText = recipe?.title ?? 'Rezept';
        subtitle = '${recipe?.prepMinutes ?? 0} Min';
      case SlotType.leftover:
        leading = '♻️';
        titleText = recipe?.title ?? 'Reste';
        subtitle = 'Reste vom Vorkochen';
      case SlotType.order:
        leading = '🛵';
        titleText = slot.note?.isNotEmpty == true ? slot.note! : 'Bestellen';
        subtitle = 'Auswärts / Lieferung';
      case SlotType.empty:
        leading = '＋';
        titleText = 'Hinzufügen';
        subtitle = null;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openSheet(context, app, slot, recipe?.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(meal.shortLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )),
                  const SizedBox(height: 2),
                  Text(leading, style: const TextStyle(fontSize: 22)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titleText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: slot.isEmpty ? scheme.onSurfaceVariant : null,
                      )),
                  if (subtitle != null)
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    AppState app,
    MealSlot slot,
    String? recipeId,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Rezept wählen'),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            if (recipeId != null)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Rezept ansehen'),
                onTap: () => Navigator.pop(context, 'view'),
              ),
            ListTile(
              leading: const Icon(Icons.delivery_dining),
              title: const Text('Bestellen / auswärts'),
              onTap: () => Navigator.pop(context, 'order'),
            ),
            if (!slot.isEmpty)
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Leeren'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'pick':
        final recipe = await Navigator.push<Recipe>(
          context,
          MaterialPageRoute(builder: (_) => RecipePickerScreen(meal: meal)),
        );
        if (recipe != null) {
          await app.updateSlot(
            dayIndex,
            meal,
            MealSlot(
              type: SlotType.cook,
              recipeId: recipe.id,
              servings: app.household.persons,
            ),
          );
        }
      case 'view':
        if (recipeId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipeId: recipeId)),
          );
        }
      case 'order':
        await app.updateSlot(
            dayIndex, meal, const MealSlot(type: SlotType.order));
      case 'clear':
        await app.updateSlot(dayIndex, meal, const MealSlot.empty());
    }
  }
}
