import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/nutrition_calc.dart';
import '../../state/app_state.dart';
import '../../widgets/nutrition_widgets.dart';

/// Full nutrition breakdown for the current week.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final analysis = app.currentAnalysis;
    return Scaffold(
      appBar: AppBar(title: const Text('Nährwerte der Woche')),
      body: analysis == null
          ? const Center(child: Text('Noch kein Plan vorhanden.'))
          : _body(context, analysis),
    );
  }

  Widget _body(BuildContext context, PlanAnalysis a) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Text('Ø pro Person und Tag',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${a.recipeMeals} gekochte Mahlzeiten · ${a.orderMeals} bestellt · '
          '${a.persons} Personen',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        NutrientBars(values: a.perPersonPerDay),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: VarietyProgress(
              count: a.varietyCount,
              target: a.varietyTarget,
              produce: a.produce,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Die Balken zeigen den Anteil am empfohlenen Tagesbedarf (DACH-'
          'Referenzwerte). Grün = Makronährstoffe, orange = Mikronährstoffe.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
