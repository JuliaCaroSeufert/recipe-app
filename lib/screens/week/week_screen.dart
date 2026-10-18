import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../models/week_plan.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/slot_card.dart';
import '../../widgets/ui_kit.dart';
import '../archive/archive_screen.dart';
import '../plan/meal_picker.dart';
import '../recipes/recipe_detail.dart';
import '../recipes/recipes_screen.dart';
import 'generate_screen.dart';
import 'nutrition_screen.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.currentPlan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wochenplan'),
        actions: [
          if (plan != null)
            IconButton(
              icon: const Icon(Icons.view_carousel_outlined),
              tooltip: 'Vorschläge durchblättern',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MealPickerScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Archiv & Recycling',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArchiveScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GenerateScreen())),
        icon: const Icon(Icons.auto_awesome),
        label: Text(plan == null ? 'Woche planen' : 'Neu planen'),
      ),
      body: plan == null
          ? EmptyState(
              emoji: '🗓️',
              title: 'Keine Woche geplant',
              message:
                  'Erstelle dir einen ausgewogenen Wochenplan für Mittag- und '
                  'Abendessen – inklusive Batch-Cooking und Gemüse-Vielfalt.',
              action: FilledButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GenerateScreen())),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Woche planen'),
              ),
            )
          : _PlanBody(
              plan: plan,
              selected: _selected.clamp(0, plan.days.length - 1),
              onSelect: (i) => setState(() => _selected = i),
            ),
    );
  }
}

class _PlanBody extends StatelessWidget {
  final WeekPlan plan;
  final int selected;
  final ValueChanged<int> onSelect;
  const _PlanBody(
      {required this.plan, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final analysis = app.currentAnalysis!;
    final day = plan.days[selected];
    final meals = day.meals.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Week variety + macros summary.
        SoftCard(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NutritionScreen())),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        weekRangeLabel(plan.startDate, plan.days.length),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const Icon(Icons.insights_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              _VarietyBar(
                  count: analysis.varietyCount, target: analysis.varietyTarget),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _MiniStat(
                          value: '${analysis.perPersonPerDay.kcal.round()}',
                          label: 'kcal / Tag')),
                  Expanded(
                      child: _MiniStat(
                          value:
                              '${analysis.perPersonPerDay.protein.round()} g',
                          label: 'Eiweiß / Tag')),
                  Expanded(
                      child: _MiniStat(
                          value: '${analysis.recipeMeals}',
                          label: 'Gerichte')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Day selector strip.
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: plan.days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _DayChip(
              date: plan.days[i].date,
              selected: i == selected,
              onTap: () => onSelect(i),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('${weekdayName(day.date)}, ${dayMonth(day.date)}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),

        for (final meal in meals) ...[
          slotCard(
            context,
            meal: meal,
            slot: day.slot(meal),
            recipe: app.recipeById(day.slot(meal).recipeId),
            onTap: () => _openSheet(context, app, selected, meal),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _openSheet(
      BuildContext context, AppState app, int dayIndex, MealType meal) async {
    final slot = plan.days[dayIndex].slot(meal);
    final recipeId = slot.recipeId;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.view_carousel_outlined),
              title: const Text('Vorschläge durchblättern'),
              onTap: () => Navigator.pop(context, 'browse'),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu_rounded),
              title: const Text('Rezept aus Liste wählen'),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            if (recipeId != null)
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Rezept ansehen'),
                onTap: () => Navigator.pop(context, 'view'),
              ),
            ListTile(
              leading: const Icon(Icons.delivery_dining_rounded),
              title: const Text('Bestellen / auswärts'),
              onTap: () => Navigator.pop(context, 'order'),
            ),
            if (!slot.isEmpty)
              ListTile(
                leading: const Icon(Icons.clear_rounded),
                title: const Text('Leeren'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'browse':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MealPickerScreen(slots: [(dayIndex, meal)]),
          ),
        );
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

class _DayChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip(
      {required this.date, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = _sameDay(date, DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _wd(date),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? Colors.white70 : scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? Colors.white : scheme.onSurface,
                  ),
            ),
            if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : scheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _wd(DateTime d) =>
      const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][d.weekday - 1];
}

class _VarietyBar extends StatelessWidget {
  final int count;
  final int target;
  const _VarietyBar({required this.count, required this.target});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reached = count >= target;
    final ratio = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(reached ? '🥦' : '🥦',
                style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text('$count von $target Gemüse-Sorten',
                style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            if (reached)
              Text('Ziel erreicht 🎉',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.greenDeep,
                      )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: scheme.surfaceContainerHighest,
            color: reached ? AppColors.green : AppColors.berry,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}
