import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../models/week_plan.dart';
import '../theme.dart';
import 'meal_card.dart';
import 'recipe_photo.dart';
import 'ui_kit.dart';

({IconData icon, Color accent}) mealStyle(MealType meal) => switch (meal) {
      MealType.lunch => (icon: Icons.wb_sunny_outlined, accent: AppColors.amber),
      MealType.dinner => (icon: Icons.nightlight_round, accent: AppColors.berry),
    };

Widget _iconTile(BuildContext context, String emoji) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
    ),
    alignment: Alignment.center,
    child: Text(emoji, style: const TextStyle(fontSize: 34)),
  );
}

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

  Widget leading;
  String title;
  String? subtitle;
  final badges = <Widget>[];
  var dim = false;

  switch (slot.type) {
    case SlotType.cook:
      leading = recipe != null
          ? RecipePhoto(recipe: recipe, radius: 18, emojiSize: 34)
          : _iconTile(context, '🍽️');
      title = recipe?.title ?? 'Rezept';
      subtitle =
          '${recipe?.prepMinutes ?? 0} Min · ${recipe?.nutritionPerServing.kcal.round() ?? 0} kcal';
      if (recipe?.isVegan ?? false) {
        badges.add(const Pill('vegan',
            background: Color(0x1A15B79E), color: AppColors.greenDeep));
      } else if (recipe?.isVegetarian ?? false) {
        badges.add(const Pill('vegetarisch'));
      }
    case SlotType.leftover:
      leading = recipe != null
          ? RecipePhoto(recipe: recipe, radius: 18, emojiSize: 34)
          : _iconTile(context, '♻️');
      title = recipe?.title ?? 'Reste';
      subtitle = 'Reste vom Vorkochen';
      badges.add(Pill('Reste',
          icon: Icons.restore,
          color: scheme.secondary,
          background: scheme.secondary.withValues(alpha: 0.12)));
    case SlotType.order:
      leading = _iconTile(context, '🛵');
      title = slot.note?.isNotEmpty == true ? slot.note! : 'Bestellen';
      subtitle = 'Auswärts / Lieferung';
    case SlotType.empty:
      leading = _iconTile(context, '＋');
      title = 'Hinzufügen';
      dim = true;
  }

  return MealCard(
    mealLabel: meal.shortLabel,
    mealIcon: style.icon,
    accent: style.accent,
    leading: leading,
    title: title,
    subtitle: subtitle,
    badges: badges,
    dim: dim,
    onTap: onTap,
  );
}
