import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/spoonacular.dart';
import '../../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dislikeCtrl = TextEditingController();
  late final TextEditingController _geminiCtrl =
      TextEditingController(text: context.read<AppState>().household.geminiApiKey);
  late final TextEditingController _spoonCtrl = TextEditingController(
      text: context.read<AppState>().household.spoonacularApiKey);

  bool _loadingPhotos = false;
  int _photoDone = 0;
  int _photoTotal = 0;

  @override
  void dispose() {
    _dislikeCtrl.dispose();
    _geminiCtrl.dispose();
    _spoonCtrl.dispose();
    super.dispose();
  }

  void _saveGeminiKey(AppState app) {
    app.saveHousehold(app.household.copyWith(geminiApiKey: _geminiCtrl.text.trim()));
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('KI-Schlüssel gespeichert.')),
    );
  }

  void _saveSpoonKey(AppState app) {
    app.saveHousehold(
        app.household.copyWith(spoonacularApiKey: _spoonCtrl.text.trim()));
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Spoonacular-Schlüssel gespeichert.')),
    );
  }

  /// Fetches a real photo for each recipe and stores it locally. With
  /// [overwrite] it also replaces photos that are already set.
  Future<void> _loadPhotos(AppState app, {bool overwrite = false}) async {
    final key = _spoonCtrl.text.trim();
    if (key.isEmpty) {
      _saveSpoonKey(app);
      return;
    }
    // Persist the key first so it's saved even if the user typed a new one.
    if (key != app.household.spoonacularApiKey) {
      await app.saveHousehold(app.household.copyWith(spoonacularApiKey: key));
    }
    if (!mounted) return;
    final todo = app.recipes
        .where((r) => overwrite || r.imageUrl.isEmpty)
        .toList();
    if (todo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alle Rezepte haben schon ein Foto. 🎉')),
      );
      return;
    }
    setState(() {
      _loadingPhotos = true;
      _photoDone = 0;
      _photoTotal = todo.length;
    });
    FocusScope.of(context).unfocus();

    var updated = 0;
    String? errorMessage;
    for (final r in todo) {
      try {
        final url = await fetchSpoonacularImage(spoonacularQuery(r), apiKey: key);
        if (url != null) {
          await app.saveRecipe(r.copyWith(imageUrl: url));
          updated++;
        }
      } on SpoonacularException catch (e) {
        errorMessage = e.message;
        break;
      } catch (e) {
        errorMessage = 'Unerwarteter Fehler: $e';
        break;
      }
      if (!mounted) return;
      setState(() => _photoDone++);
    }

    if (!mounted) return;
    setState(() => _loadingPhotos = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage ??
            '$updated ${updated == 1 ? 'Foto' : 'Fotos'} geladen. 📸'),
      ),
    );
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
            'Gerichte mit diesen Zutaten werden bei Vorschlägen übersprungen. '
            'Schreibweise, Groß-/Kleinschreibung und Ein-/Mehrzahl sind egal.',
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

          _title('KI-Import (Gemini)'),
          Text(
            'Mit einem kostenlosen Google-Gemini-Schlüssel erkennt die App '
            'geteilte Instagram-Rezepte automatisch. Schlüssel gratis holen '
            'unter aistudio.google.com/apikey – wird nur hier auf dem Gerät '
            'gespeichert.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _geminiCtrl,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Gemini-Schlüssel (AIza…)',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _saveGeminiKey(app),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _saveGeminiKey(app),
                icon: const Icon(Icons.save),
              ),
            ],
          ),
          if (h.hasAiKey)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '✓ KI-Import aktiv',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),

          _title('Rezept-Fotos (Spoonacular)'),
          Text(
            'Mit einem kostenlosen Spoonacular-Schlüssel lädt die App echte, '
            'hochwertige Fotos zu deinen Rezepten. Schlüssel gratis holen unter '
            'spoonacular.com/food-api (Konto anlegen → „API Key", keine '
            'Kreditkarte nötig). Wird nur hier auf dem Gerät gespeichert, und '
            'die Fotos bleiben dann offline verfügbar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _spoonCtrl,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Spoonacular-Schlüssel',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _saveSpoonKey(app),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _loadingPhotos ? null : () => _saveSpoonKey(app),
                icon: const Icon(Icons.save),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingPhotos)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _photoTotal == 0 ? null : _photoDone / _photoTotal,
                ),
                const SizedBox(height: 6),
                Text('Lade Fotos … $_photoDone / $_photoTotal',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _loadPhotos(app),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Fotos laden'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _loadPhotos(app, overwrite: true),
                  child: const Text('Alle neu'),
                ),
              ],
            ),
          if (app.household.hasSpoonacularKey && !_loadingPhotos)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '✓ Schlüssel gespeichert · '
                '${app.recipes.where((r) => r.imageUrl.isNotEmpty).length}'
                '/${app.recipes.length} Rezepte mit Foto',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
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
