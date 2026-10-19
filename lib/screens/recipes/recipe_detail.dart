import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recipe = app.recipeById(widget.recipeId);
    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('Rezept nicht gefunden.')));
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final servings = _servings ?? app.household.persons;
    final factor =
        recipe.baseServings == 0 ? 1.0 : servings / recipe.baseServings;
    final n = recipe.nutritionPerServing;

    return Scaffold(
      backgroundColor: dark ? AppColors.darkBg : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: dark ? AppColors.darkBg : Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 60,
            leading: _RoundIcon(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
            ),
            actions: [
              _RoundIcon(
                icon: Icons.edit_outlined,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RecipeEditScreen(existing: recipe))),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  RecipePhoto(recipe: recipe, radius: 0, emojiSize: 96),
                  // Subtle top scrim so the round buttons stay legible.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x3D000000), Color(0x00000000)],
                        stops: [0, 0.28],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time · kcal, centered.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stat(context, Icons.schedule_rounded,
                          '${recipe.prepMinutes} Min'),
                      Container(
                        width: 1,
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        color: scheme.outlineVariant,
                      ),
                      _stat(context, Icons.local_fire_department_rounded,
                          '${n.kcal.round()} kcal'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(recipe.title, style: theme.textTheme.headlineMedium),
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(recipe.description,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],

                  const SizedBox(height: 18),
                  Divider(height: 1, color: scheme.outlineVariant),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _action(
                          context,
                          icon: _saved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: 'Speichern',
                          color: _saved ? scheme.tertiary : null,
                          onTap: () => setState(() => _saved = !_saved),
                        ),
                      ),
                      Container(
                          width: 1, height: 28, color: scheme.outlineVariant),
                      Expanded(
                        child: _action(
                          context,
                          icon: Icons.ios_share_rounded,
                          label: 'Teilen',
                          onTap: () => _share(context, recipe, factor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: scheme.outlineVariant),
                  const SizedBox(height: 18),

                  // Brand / author row.
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.green,
                        child: const Icon(Icons.soup_kitchen_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Essensplan',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: AppColors.greenDeep)),
                          Text('@essensplan',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final t in _tags(recipe)) TagPill(t)],
                  ),

                  const SizedBox(height: 26),
                  // Portions stepper.
                  Row(
                    children: [
                      Text('Portionen', style: theme.textTheme.titleLarge),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: servings > 1
                            ? () => setState(() => _servings = servings - 1)
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('$servings',
                            style: theme.textTheme.titleLarge),
                      ),
                      IconButton.filledTonal(
                        onPressed: () =>
                            setState(() => _servings = servings + 1),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
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

                  const SizedBox(height: 28),
                  Text('Zutaten', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  for (final ing in recipe.ingredients)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            ing.countsAsVariety
                                ? Icons.eco_rounded
                                : Icons.fiber_manual_record,
                            size: ing.countsAsVariety ? 17 : 7,
                            color: ing.countsAsVariety
                                ? AppColors.green
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(ing.name,
                                  style: theme.textTheme.bodyLarge)),
                          Text(_amount(ing.amount * factor, ing.unit),
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  Text('Zubereitung', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  for (var i = 0; i < recipe.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${i + 1}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppColors.greenDeep,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(recipe.steps[i],
                                  style: theme.textTheme.bodyLarge),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 26),
                  Text('Nährwerte pro Portion',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 14),
                  NutrientBars(values: n),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        onOptions: () => _showOptions(context, app, recipe),
        onPlan: () => _addToPlan(context, app, recipe),
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _action(BuildContext context,
      {required IconData icon,
      required String label,
      Color? color,
      required VoidCallback onTap}) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: c),
            const SizedBox(width: 9),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: c)),
          ],
        ),
      ),
    );
  }

  List<String> _tags(Recipe r) {
    final n = r.nutritionPerServing;
    final out = <String>[];
    if (n.protein >= 20) out.add('Protein');
    if (n.fiber >= 9) out.add('Ballaststoffreich');
    if (r.isVegan) {
      out.add('Vegan');
    } else if (r.isVegetarian) {
      out.add('Vegetarisch');
    }
    if (r.isQuick) out.add('Schnell');
    if (r.batchFriendly) out.add('Gut vorzukochen');
    if (n.iron >= 4.5) out.add('Eisenreich');
    if (n.vitaminC >= 60) out.add('Vitamin C');
    return out;
  }

  void _share(BuildContext context, Recipe recipe, double factor) {
    final b = StringBuffer()
      ..writeln(recipe.title)
      ..writeln()
      ..writeln('Zutaten:');
    for (final ing in recipe.ingredients) {
      final amt = _amount(ing.amount * factor, ing.unit);
      b.writeln('• ${amt.isEmpty ? '' : '$amt '}${ing.name}');
    }
    b.writeln();
    b.writeln('Zubereitung:');
    for (var i = 0; i < recipe.steps.length; i++) {
      b.writeln('${i + 1}. ${recipe.steps[i]}');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rezept in die Zwischenablage kopiert.')),
    );
  }

  Future<void> _showOptions(
      BuildContext context, AppState app, Recipe recipe) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Bearbeiten'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RecipeEditScreen(existing: recipe)));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Löschen',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context, app, recipe);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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

/// Fixed bottom action bar (Optionen · Zum Plan), like modern recipe apps.
class _BottomBar extends StatelessWidget {
  final VoidCallback onOptions;
  final VoidCallback onPlan;
  const _BottomBar({required this.onOptions, required this.onPlan});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : Colors.white,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOptions,
                icon: const Icon(Icons.tune_rounded, size: 20),
                label: const Text('Optionen'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onPlan,
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Zum Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 21, color: AppColors.ink),
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
