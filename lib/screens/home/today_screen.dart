import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nutrition.dart';
import '../../models/week_plan.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/slot_card.dart';
import '../../widgets/ui_kit.dart';
import '../recipes/instagram_import.dart';
import '../recipes/recipe_detail.dart';
import '../settings/settings_screen.dart';
import '../week/generate_screen.dart';
import '../week/nutrition_screen.dart';

class TodayScreen extends StatelessWidget {
  /// Switches the bottom-nav tab (set by [HomeShell]).
  final ValueChanged<int> onOpenTab;
  const TodayScreen({super.key, required this.onOpenTab});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Guten Morgen';
    if (h < 17) return 'Mahlzeit';
    return 'Guten Abend';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.currentPlan;
    final today = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Header(greeting: _greeting()),
            const SizedBox(height: 18),
            if (plan == null)
              _NoPlan(onPlan: () => _openGenerate(context))
            else ...[
              _TodaySection(plan: plan, today: today, onOpenTab: onOpenTab),
              const SizedBox(height: 22),
              _WeekProgress(onDetails: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NutritionScreen()))),
              const SizedBox(height: 22),
            ],
            const _Featured(),
            const SizedBox(height: 22),
            _QuickActions(
              onPlan: () => _openGenerate(context),
              onShop: () => onOpenTab(3),
              onImport: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const InstagramImportScreen())),
            ),
          ],
        ),
      ),
    );
  }

  void _openGenerate(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const GenerateScreen()));
}

class _Header extends StatelessWidget {
  final String greeting;
  const _Header({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting 👋',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(
                'Heute, ${weekdayName(DateTime.now())} · ${dayMonth(DateTime.now())}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _TodaySection extends StatelessWidget {
  final WeekPlan plan;
  final DateTime today;
  final ValueChanged<int> onOpenTab;
  const _TodaySection(
      {required this.plan, required this.today, required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final idx = plan.days.indexWhere((d) =>
        d.date.year == today.year &&
        d.date.month == today.month &&
        d.date.day == today.day);

    if (idx < 0) {
      return SoftCard(
        onTap: () => onOpenTab(1),
        child: Row(
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Heute liegt außerhalb deines Plans '
                '(${weekRangeLabel(plan.startDate, plan.days.length)}). '
                'Tippe, um die Woche zu öffnen.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final day = plan.days[idx];
    final meals = day.meals.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Heute auf dem Teller',
          trailing: TextButton(
            onPressed: () => onOpenTab(1),
            child: const Text('Woche'),
          ),
        ),
        for (final meal in meals) ...[
          slotCard(
            context,
            meal: meal,
            slot: day.slot(meal),
            recipe: app.recipeById(day.slot(meal).recipeId),
            onTap: () {
              final slot = day.slot(meal);
              if (slot.hasRecipe && slot.recipeId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          RecipeDetailScreen(recipeId: slot.recipeId!)),
                );
              } else {
                onOpenTab(1);
              }
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _WeekProgress extends StatelessWidget {
  final VoidCallback onDetails;
  const _WeekProgress({required this.onDetails});

  double _target(String key) =>
      kNutrients.firstWhere((n) => n.key == key).dailyPerPerson;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final a = app.currentAnalysis;
    if (a == null) return const SizedBox.shrink();
    final ppd = a.perPersonPerDay;

    return SoftCard(
      onTap: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Deine Woche',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('Details',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      )),
              Icon(Icons.chevron_right,
                  size: 18, color: Theme.of(context).colorScheme.primary),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ProgressRing(
                value: ppd.kcal / _target('kcal'),
                color: AppColors.amber,
                centerText: '${ppd.kcal.round()}',
                label: 'kcal/Tag',
              ),
              ProgressRing(
                value: ppd.protein / _target('protein'),
                color: AppColors.green,
                centerText: '${ppd.protein.round()}g',
                label: 'Eiweiß',
              ),
              ProgressRing(
                value: a.varietyTarget == 0
                    ? 0
                    : a.varietyCount / a.varietyTarget,
                color: AppColors.berry,
                centerText: '${a.varietyCount}',
                label: '/${a.varietyTarget} Gemüse',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onPlan;
  final VoidCallback onShop;
  final VoidCallback onImport;
  const _QuickActions(
      {required this.onPlan, required this.onShop, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Schnellstart'),
        Row(
          children: [
            Expanded(
                child: _Action(
                    emoji: '✨',
                    label: 'Woche\nplanen',
                    color: AppColors.green,
                    onTap: onPlan)),
            const SizedBox(width: 12),
            Expanded(
                child: _Action(
                    emoji: '🛒',
                    label: 'Einkaufs-\nliste',
                    color: AppColors.coral,
                    onTap: onShop)),
            const SizedBox(width: 12),
            Expanded(
                child: _Action(
                    emoji: '📸',
                    label: 'Rezept\nimportieren',
                    color: AppColors.berry,
                    onTap: onImport)),
          ],
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action(
      {required this.emoji,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recipes = app.recipes;
    if (recipes.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final doy = now.difference(DateTime(now.year)).inDays;
    final Recipe r = recipes[doy % recipes.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Tipp des Tages'),
        SoftCard(
          padding: EdgeInsets.zero,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipePhoto(
                  recipe: r,
                  width: double.infinity,
                  height: 170,
                  radius: 0,
                  emojiSize: 72),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final h in r.highlights)
                          Pill(h,
                              color: AppColors.greenDeep,
                              background: const Color(0x141E9E63)),
                        Pill('${r.prepMinutes} Min',
                            icon: Icons.schedule_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoPlan extends StatelessWidget {
  final VoidCallback onPlan;
  const _NoPlan({required this.onPlan});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Text('🥗', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text('Noch nichts geplant',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Lass dir in wenigen Sekunden eine ausgewogene Woche vorschlagen – '
            'mit Batch-Cooking, Bestell-Tagen und viel Gemüse.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPlan,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Woche planen'),
          ),
        ],
      ),
    );
  }
}
