import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../models/week_plan.dart';
import '../theme.dart';
import 'meal_card.dart';
import 'ui_kit.dart';

({IconData icon, Color accent}) mealStyle(MealType meal) => switch (meal) {
      MealType.lunch => (icon: Icons.wb_sunny_outlined, accent: AppColors.amber),
      MealType.dinner => (icon: Icons.nightlight_round, accent: AppColors.berry),
    };

/// Builds a [MealCard] for one slot, resolving recipe/leftover/order/empty.
Widget slotCard(
  BuildContext context, {
  required MealType meal,
  required MealSlot slot,
  required Recipe? recipe,
  required VoidCallback onTap,
}) {
  final style = mealStyle(meal);
  final scheme = Theme.of(context).colorScheme;

  String emoji;
  String title;
  String? subtitle;
  final badges = <Widget>[];
  var empty = false;

  switch (slot.type) {
    case SlotType.cook:
      emoji = recipe?.emoji ?? '🍽️';
      title = recipe?.title ?? 'Rezept';
      subtitle =
          '${recipe?.prepMinutes ?? 0} Min · ${recipe?.nutritionPerServing.kcal.round() ?? 0} kcal';
      if (recipe?.isVegan ?? false) {
        badges.add(const Pill('vegan', background: Color(0x1A1E9E63),
            color: AppColors.greenDeep));
      } else if (recipe?.isVegetarian ?? false) {
        badges.add(const Pill('vegetarisch'));
      }
    case SlotType.leftover:
      emoji = recipe?.emoji ?? '♻️';
      title = recipe?.title ?? 'Reste';
      subtitle = 'Reste vom Vorkochen';
      badges.add(Pill('Reste', icon: Icons.restore,
          color: scheme.secondary, background: scheme.secondary.withValues(alpha: 0.12)));
    case SlotType.order:
      emoji = '🛵';
      title = slot.note?.isNotEmpty == true ? slot.note! : 'Bestellen';
      subtitle = 'Auswärts / Lieferung';
    case SlotType.empty:
      emoji = '➕';
      title = 'Hinzufügen';
      empty = true;
  }

  return MealCard(
    mealLabel: meal.shortLabel,
    mealIcon: style.icon,
    accent: style.accent,
    emoji: emoji,
    seed: recipe?.title ?? meal.name,
    title: title,
    subtitle: subtitle,
    badges: badges,
    empty: empty,
    onTap: onTap,
  );
}
