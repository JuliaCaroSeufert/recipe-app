import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/instagram_parse.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import 'recipe_edit.dart';

/// Import a recipe from Instagram by pasting the post/reel caption. The app
/// parses it live into a draft (ingredients categorised, vegetables tagged,
/// nutrition estimated) and the user can save directly or fine-tune first.
///
/// Automatic fetching of other creators' posts isn't possible (Instagram's API
/// doesn't cover them and scraping breaches their terms), so the user pastes
/// the text they already see in the app.
class InstagramImportScreen extends StatefulWidget {
  const InstagramImportScreen({super.key});

  @override
  State<InstagramImportScreen> createState() => _InstagramImportScreenState();
}

class _InstagramImportScreenState extends State<InstagramImportScreen> {
  final _url = TextEditingController();
  final _caption = TextEditingController();
  Recipe? _draft;

  @override
  void dispose() {
    _url.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _reparse() {
    final text = _caption.text.trim();
    setState(() {
      _draft = text.isEmpty
          ? null
          : parseInstagramCaption(
              _caption.text,
              url: _url.text.trim().isEmpty ? null : _url.text.trim(),
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Aus Instagram importieren')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Öffne das Reel/den Post in Instagram, kopiere die '
                    'Beschreibung und füge sie unten ein. Die App erkennt '
                    'Zutaten, Mengen und Schritte – prüfe die Vorschau und '
                    'speichere.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            onChanged: (_) => _reparse(),
            decoration: const InputDecoration(
              labelText: 'Instagram-Link (optional)',
              hintText: 'https://www.instagram.com/reel/...',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            onChanged: (_) => _reparse(),
            decoration: const InputDecoration(
              labelText: 'Caption / Beschreibung einfügen',
              alignLabelWithHint: true,
            ),
            minLines: 6,
            maxLines: 16,
          ),
          const SizedBox(height: 16),
          if (draft != null) _Preview(draft: draft),
          if (draft != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _saveDirect(context, draft),
              icon: const Icon(Icons.check),
              label: const Text('Direkt speichern'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => RecipeEditScreen(initial: draft)),
              ),
              icon: const Icon(Icons.tune),
              label: const Text('Anpassen & speichern'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveDirect(BuildContext context, Recipe draft) async {
    await context.read<AppState>().saveRecipe(draft);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${draft.title}" gespeichert.')),
      );
    }
  }
}

class _Preview extends StatelessWidget {
  final Recipe draft;
  const _Preview({required this.draft});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kcal = draft.nutritionPerServing.kcal.round();
    final recognised = draft.ingredients
        .where((i) => i.category != IngredientCategory.other)
        .length;
    final veg = draft.produceKeys;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vorschau', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(draft.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(draft.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${draft.prepMinutes} Min · ${draft.baseServings} Portionen'
              '${kcal > 0 ? ' · ~$kcal kcal/Portion (geschätzt)' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (draft.tags.where((t) => t != 'instagram').isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in draft.tags.where((t) => t != 'instagram'))
                    Chip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
            const Divider(height: 20),
            Text('Zutaten (${draft.ingredients.length}, davon $recognised erkannt)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (draft.ingredients.isEmpty)
              Text('Keine Zutaten erkannt – füge sie beim Anpassen hinzu.',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              for (final ing in draft.ingredients)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(ing.countsAsVariety ? '🥦' : '•',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(ing.name)),
                      if (ing.amount > 0)
                        Text(
                          '${ing.amount == ing.amount.roundToDouble() ? ing.amount.round() : ing.amount} ${ing.unit}'
                              .trim(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
            if (veg.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Zählt für Gemüse-Vielfalt: ${veg.join(', ')}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.primary)),
            ],
            const Divider(height: 20),
            Text('${draft.steps.length} Zubereitungsschritte erkannt',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
