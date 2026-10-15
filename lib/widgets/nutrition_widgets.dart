import 'package:flutter/material.dart';

import '../models/nutrition.dart';

/// Horizontal progress toward the weekly vegetable/legume variety goal.
class VarietyProgress extends StatelessWidget {
  final int count;
  final int target;
  final Set<String> produce;

  const VarietyProgress({
    super.key,
    required this.count,
    required this.target,
    this.produce = const {},
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reached = count >= target;
    final ratio = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
    final sorted = produce.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(reached ? '🥦✅' : '🥦',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gemüse & Hülsenfrüchte: $count von $target Sorten',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: scheme.surfaceContainerHighest,
            color: reached ? scheme.primary : scheme.tertiary,
          ),
        ),
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in sorted)
                Chip(
                  label: Text(p),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A compact stat tile (value + label).
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }
}

/// A full nutrient breakdown: each nutrient as a bar vs. a reference value.
/// [values] is the amount to show per nutrient; [reference] is 100% for the
/// bar. Pass per-person-per-day values with the daily reference, or per-serving
/// values with the daily reference for a single meal.
class NutrientBars extends StatelessWidget {
  final Nutrition values;

  /// Multiplier on each nutrient's [NutrientInfo.dailyPerPerson] to form 100%.
  final double referenceFactor;
  final bool macrosOnly;

  const NutrientBars({
    super.key,
    required this.values,
    this.referenceFactor = 1.0,
    this.macrosOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list =
        macrosOnly ? kNutrients.where((n) => n.isMacro).toList() : kNutrients;
    return Column(
      children: [
        for (final n in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: _row(context, scheme, n),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, ColorScheme scheme, NutrientInfo n) {
    final value = values.byKey(n.key);
    final reference = n.dailyPerPerson * referenceFactor;
    final ratio = reference == 0 ? 0.0 : (value / reference).clamp(0.0, 1.0);
    final pct = reference == 0 ? 0 : (value / reference * 100).round();
    final valueText = value >= 100 ? value.round().toString() : value.toStringAsFixed(value < 10 ? 1 : 0);
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(n.label,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: n.isMacro ? scheme.primary : scheme.tertiary,
            ),
          ),
        ),
        SizedBox(
          width: 92,
          child: Text(
            '$valueText ${n.unit}  ·  $pct%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
