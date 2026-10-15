import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dislikeCtrl = TextEditingController();

  @override
  void dispose() {
    _dislikeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final h = app.household;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _title('Haushalt'),
          _stepperTile(
            label: 'Personen',
            value: h.persons,
            min: 1,
            max: 12,
            onChanged: (v) =>
                app.saveHousehold(h.copyWith(persons: v)),
          ),
          _stepperTile(
            label: 'Gemüse-Ziel pro Woche',
            value: h.weeklyVarietyTarget,
            min: 5,
            max: 40,
            onChanged: (v) =>
                app.saveHousehold(h.copyWith(weeklyVarietyTarget: v)),
          ),

          _title('Ernährung'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nur vegetarische Vorschläge'),
            value: h.vegetarianOnly,
            onChanged: (v) => app.saveHousehold(h.copyWith(
              vegetarianOnly: v,
              veganOnly: v ? h.veganOnly : false,
            )),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nur vegane Vorschläge'),
            value: h.veganOnly,
            onChanged: (v) => app.saveHousehold(h.copyWith(
              veganOnly: v,
              vegetarianOnly: v ? true : h.vegetarianOnly,
            )),
          ),

          _title('Mag ich nicht'),
          Text(
            'Gerichte mit diesen Zutaten werden bei Vorschlägen übersprungen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (h.dislikes.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in h.dislikes)
                  InputChip(
                    label: Text(d),
                    onDeleted: () {
                      final next = [...h.dislikes]..remove(d);
                      app.saveHousehold(h.copyWith(dislikes: next));
                    },
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dislikeCtrl,
                  decoration: const InputDecoration(
                    hintText: 'z. B. Pilze, Koriander',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addDislike(app),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _addDislike(app),
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          _title('Rezepte'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore),
            title: const Text('Mitgelieferte Rezepte wiederherstellen'),
            subtitle: const Text(
                'Fügt die Standard-Rezepte wieder hinzu (eigene bleiben).'),
            onTap: () async {
              await app.restoreSeedRecipes();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rezepte wiederhergestellt.')),
                );
              }
            },
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Essensplan · offline · ${app.recipes.length} Rezepte',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _addDislike(AppState app) {
    final value = _dislikeCtrl.text.trim().toLowerCase();
    if (value.isEmpty) return;
    final h = app.household;
    if (h.dislikes.contains(value)) {
      _dislikeCtrl.clear();
      return;
    }
    app.saveHousehold(h.copyWith(dislikes: [...h.dislikes, value]));
    _dislikeCtrl.clear();
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _stepperTile({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$value',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton.filledTonal(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
