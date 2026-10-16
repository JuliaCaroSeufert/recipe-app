import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/plan_generator.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../utils/dates.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  static const int _numDays = 7;

  late DateTime _start;
  final Set<MealType> _meals = {MealType.lunch, MealType.dinner};
  late int _persons;
  int _batchSessions = 1;
  int _batchSpan = 4;
  final Set<String> _orderSlots = {};

  @override
  void initState() {
    super.initState();
    _start = mondayOf(DateTime.now(), upcoming: true);
    _persons = context.read<AppState>().household.persons;
  }

  List<MealType> get _orderedMeals =>
      _meals.toList()..sort((a, b) => a.index.compareTo(b.index));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Startdatum der Woche',
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _generate() async {
    if (_meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte mindestens eine Mahlzeit wählen.')),
      );
      return;
    }
    final app = context.read<AppState>();
    if (_persons != app.household.persons) {
      await app.saveHousehold(app.household.copyWith(persons: _persons));
    }
    await app.generatePlan(GenerateConfig(
      startDate: _start,
      numDays: _numDays,
      meals: _orderedMeals,
      orderSlots: _orderSlots,
      batchSessions: _batchSessions,
      batchSpan: _batchSpan,
      label: 'Woche ${_start.day}.${_start.month}.',
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Woche planen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _sectionTitle('Start'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Startdatum'),
              subtitle: Text('${weekdayName(_start)}, ${shortDate(_start)}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
          ),

          _sectionTitle('Mahlzeiten pro Tag'),
          Wrap(
            spacing: 8,
            children: [
              for (final m in MealType.values)
                FilterChip(
                  label: Text(m.label),
                  selected: _meals.contains(m),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _meals.add(m);
                    } else {
                      _meals.remove(m);
                      _orderSlots.removeWhere((k) => k.endsWith(m.name));
                    }
                  }),
                ),
            ],
          ),

          _sectionTitle('Für wie viele Personen?'),
          _stepper(
            value: _persons,
            min: 1,
            max: 12,
            onChanged: (v) => setState(() => _persons = v),
            label: '$_persons Personen',
          ),

          _sectionTitle('Batch-Cooking'),
          Text(
            'Einmal kochen, mehrfach essen. Wähle, wie viele Gerichte '
            'vorgekocht werden und für wie viele Mahlzeiten sie reichen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _stepper(
            value: _batchSessions,
            min: 0,
            max: 4,
            onChanged: (v) => setState(() => _batchSessions = v),
            label: _batchSessions == 0
                ? 'Kein Vorkochen'
                : '$_batchSessions Gericht(e) vorkochen',
          ),
          if (_batchSessions > 0)
            _stepper(
              value: _batchSpan,
              min: 2,
              max: 4,
              onChanged: (v) => setState(() => _batchSpan = v),
              label: 'je für $_batchSpan Mahlzeiten',
            ),

          _sectionTitle('Bestell-Tage (auswärts/Lieferung)'),
          Text(
            'Tippe die Mahlzeiten an, die du lieber bestellst – dafür wird '
            'kein Rezept eingeplant.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (var d = 0; d < _numDays; d++) _orderDayRow(d),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Plan erstellen'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _orderDayRow(int d) {
    final date = _start.add(Duration(days: d));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(weekdayName(date))),
          for (final m in _orderedMeals)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(m.shortLabel),
                selected: _orderSlots.contains(slotKey(d, m)),
                onSelected: (sel) => setState(() {
                  final key = slotKey(d, m);
                  if (sel) {
                    _orderSlots.add(key);
                  } else {
                    _orderSlots.remove(key);
                  }
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton.filledTonal(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
