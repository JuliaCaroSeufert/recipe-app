import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme.dart';

/// Small coloured-dot nutrient chips (Protein, Eisen, Calcium …) like modern
/// recipe apps. Picks the recipe's most notable nutrients.
class NutrientDots extends StatelessWidget {
  final Recipe recipe;
  final int max;
  const NutrientDots({super.key, required this.recipe, this.max = 3});

  @override
  Widget build(BuildContext context) {
    final n = recipe.nutritionPerServing;
    final items = <(String, Color)>[];
    if (n.protein >= 20) items.add(('Protein', AppColors.pink));
    if (n.fiber >= 9) items.add(('Ballaststoffe', AppColors.green));
    if (n.iron >= 4.5) items.add(('Eisen', AppColors.amber));
    if (n.calcium >= 250) items.add(('Calcium', AppColors.purple));
    if (n.vitaminC >= 60) items.add(('Vitamin C', AppColors.coral));
    if (items.isEmpty) return const SizedBox.shrink();

    final shown = items.take(max).toList();
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final (label, color) in shown)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      )),
            ],
          ),
      ],
    );
  }
}
