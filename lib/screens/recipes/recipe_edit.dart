import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/food_db.dart';
import '../../models/ingredient.dart';
import '../../models/nutrition.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';

const _uuid = Uuid();
const _units = ['', 'g', 'ml', 'Stück', 'EL', 'TL', 'Prise', 'Dose', 'Bund', 'Packung'];

class _IngDraft {
  final TextEditingController name;
  final TextEditingController amount;
  String unit;
  IngredientCategory category;
  bool isVeggie;

  _IngDraft({
    String name = '',
    String amount = '',
    this.unit = 'g',
    this.category = IngredientCategory.other,
    this.isVeggie = false,
  })  : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

/// Create a new recipe or edit an existing one. Pass [existing] to edit,
/// or [initial] to pre-fill a brand new recipe (used by the Instagram import).
class RecipeEditScreen extends StatefulWidget {
  final Recipe? existing;
  final Recipe? initial;

  const RecipeEditScreen({super.key, this.existing, this.initial});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Recipe? _base = widget.existing ?? widget.initial;

  late final TextEditingController _title =
      TextEditingController(text: _base?.title ?? '');
  late final TextEditingController _emoji =
      TextEditingController(text: _base?.emoji ?? '🍽️');
  late final TextEditingController _description =
      TextEditingController(text: _base?.description ?? '');
  late final TextEditingController _prep =
      TextEditingController(text: (_base?.prepMinutes ?? 30).toString());
  late final TextEditingController _servings =
      TextEditingController(text: (_base?.baseServings ?? 2).toString());
  late final TextEditingController _tags =
      TextEditingController(text: _base?.tags.join(', ') ?? '');

  // Macro inputs.
  late final TextEditingController _kcal = _numCtrl(_base?.nutritionPerServing.kcal);
  late final TextEditingController _protein = _numCtrl(_base?.nutritionPerServing.protein);
  late final TextEditingController _carbs = _numCtrl(_base?.nutritionPerServing.carbs);
  late final TextEditingController _fat = _numCtrl(_base?.nutritionPerServing.fat);
  late final TextEditingController _fiber = _numCtrl(_base?.nutritionPerServing.fiber);

  bool _vegetarian = false;
  bool _vegan = false;
  bool _batch = false;

  late final List<_IngDraft> _ingredients = _initIngredients();
  late final List<TextEditingController> _steps = _initSteps();

  TextEditingController _numCtrl(double? v) =>
      TextEditingController(text: (v == null || v == 0) ? '' : v.round().toString());

  List<_IngDraft> _initIngredients() {
    final base = _base;
    if (base == null || base.ingredients.isEmpty) {
      return [_IngDraft()];
    }
    return base.ingredients
        .map((i) => _IngDraft(
              name: i.name,
              amount: i.amount == 0 ? '' : i.amount.toString(),
              unit: i.unit.isEmpty ? '' : i.unit,
              category: i.category,
              isVeggie: i.produceKey != null,
            ))
        .toList();
  }

  List<TextEditingController> _initSteps() {
    final base = _base;
    if (base == null || base.steps.isEmpty) {
      return [TextEditingController()];
    }
    return base.steps.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void initState() {
    super.initState();
    _vegetarian = _base?.isVegetarian ?? false;
    _vegan = _base?.isVegan ?? false;
    _batch = _base?.batchFriendly ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _title, _emoji, _description, _prep, _servings, _tags,
      _kcal, _protein, _carbs, _fat, _fiber,
    ]) {
      c.dispose();
    }
    for (final i in _ingredients) {
      i.dispose();
    }
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();

    final ingredients = <RecipeIngredient>[];
    for (final d in _ingredients) {
      final name = d.name.text.trim();
      if (name.isEmpty) continue;
      ingredients.add(RecipeIngredient(
        name: name,
        amount: _d(d.amount),
        unit: d.unit,
        category: d.category,
        produceKey: d.isVeggie ? name : null,
      ));
    }
    final steps = _steps
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final isEditing = widget.existing != null;
    final recipe = Recipe(
      id: isEditing ? widget.existing!.id : _uuid.v4(),
      title: _title.text.trim(),
      emoji: _emoji.text.trim().isEmpty ? '🍽️' : _emoji.text.trim(),
      description: _description.text.trim(),
      prepMinutes: int.tryParse(_prep.text) ?? 30,
      baseServings: int.tryParse(_servings.text) ?? 2,
      tags: _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      isVegetarian: _vegetarian || _vegan,
      isVegan: _vegan,
      batchFriendly: _batch,
      ingredients: ingredients,
      steps: steps,
      nutritionPerServing: Nutrition(
        kcal: _d(_kcal),
        protein: _d(_protein),
        carbs: _d(_carbs),
        fat: _d(_fat),
        fiber: _d(_fiber),
      ),
      source: _base?.source ?? RecipeSource.manual,
      sourceUrl: _base?.sourceUrl,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await app.saveRecipe(recipe);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Rezept bearbeiten' : 'Neues Rezept'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    controller: _emoji,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Emoji'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Titel'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Bitte Titel angeben' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Kurzbeschreibung'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prep,
                    decoration: const InputDecoration(
                        labelText: 'Zeit (Min)', suffixText: 'Min'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servings,
                    decoration:
                        const InputDecoration(labelText: 'Basis-Portionen'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tags (mit Komma getrennt)',
                hintText: 'schnell, one-pot',
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vegetarisch'),
              value: _vegetarian,
              onChanged: (v) => setState(() {
                _vegetarian = v;
                if (!v) _vegan = false;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vegan'),
              value: _vegan,
              onChanged: (v) => setState(() {
                _vegan = v;
                if (v) _vegetarian = true;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gut zum Vorkochen (Batch)'),
              value: _batch,
              onChanged: (v) => setState(() => _batch = v),
            ),

            const Divider(height: 28),
            Text('Zutaten', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < _ingredients.length; i++)
              _ingredientRow(i),
            TextButton.icon(
              onPressed: () => setState(() => _ingredients.add(_IngDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Zutat hinzufügen'),
            ),

            const Divider(height: 28),
            Text('Zubereitung', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(radius: 12, child: Text('${i + 1}')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _steps[i],
                        decoration:
                            const InputDecoration(hintText: 'Schritt', isDense: true),
                        maxLines: null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _steps.length > 1
                          ? () => setState(() {
                                _steps.removeAt(i).dispose();
                              })
                          : null,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _steps.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Schritt hinzufügen'),
            ),

            const Divider(height: 28),
            Text('Nährwerte pro Portion (optional)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _num(_kcal, 'kcal')),
                const SizedBox(width: 8),
                Expanded(child: _num(_protein, 'Eiweiß g')),
                const SizedBox(width: 8),
                Expanded(child: _num(_fiber, 'Ballast. g')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _num(_carbs, 'KH g')),
                const SizedBox(width: 8),
                Expanded(child: _num(_fat, 'Fett g')),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _num(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: TextInputType.number,
      );

  Widget _ingredientRow(int i) {
    final d = _ingredients[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: d.name,
                  decoration:
                      const InputDecoration(hintText: 'Zutat', isDense: true),
                  onChanged: (value) {
                    // Suggest category/veggie flag from the food database,
                    // without clobbering a choice the user already made.
                    final entry = lookupFood(value);
                    if (entry == null) return;
                    setState(() {
                      if (d.category == IngredientCategory.other) {
                        d.category = entry.category;
                      }
                      if (entry.produceKey != null) d.isVeggie = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: d.amount,
                  decoration:
                      const InputDecoration(hintText: 'Menge', isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 84,
                child: DropdownButtonFormField<String>(
                  initialValue: d.unit,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final u in _units)
                      DropdownMenuItem(
                          value: u, child: Text(u.isEmpty ? '–' : u)),
                  ],
                  onChanged: (v) => setState(() => d.unit = v ?? ''),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _ingredients.length > 1
                    ? () => setState(() {
                          _ingredients.removeAt(i).dispose();
                        })
                    : null,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<IngredientCategory>(
                  initialValue: d.category,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Kategorie', isDense: true),
                  items: [
                    for (final c in IngredientCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (v) => setState(() =>
                      d.category = v ?? IngredientCategory.other),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Gemüse/\nHülsenfrucht',
                      style: TextStyle(fontSize: 12)),
                  value: d.isVeggie,
                  onChanged: (v) => setState(() => d.isVeggie = v ?? false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
