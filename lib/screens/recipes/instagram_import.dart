import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/ai_import.dart';
import '../../logic/instagram_parse.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../settings/settings_screen.dart';
import 'recipe_edit.dart';

/// Import a recipe from Instagram by pasting the post/reel caption. The app
/// parses it live into a draft (ingredients categorised, vegetables tagged,
/// nutrition estimated) and the user can save directly or fine-tune first.
///
/// Automatic fetching of other creators' posts isn't possible (Instagram's API
/// doesn't cover them and scraping breaches their terms), so the user pastes
/// the text they already see in the app.
class InstagramImportScreen extends StatefulWidget {
  /// Text handed in by the share sheet (a caption and/or a reel link).
  final String? sharedText;

  /// When true, the screen is framed as a generic "paste any recipe text"
  /// import (e.g. copied from Choosy or a blog) rather than Instagram-specific.
  final bool generic;

  const InstagramImportScreen({
    super.key,
    this.sharedText,
    this.generic = false,
  });

  @override
  State<InstagramImportScreen> createState() => _InstagramImportScreenState();
}

final RegExp _urlOnly = RegExp(r'^\s*https?://\S+\s*$');
final RegExp _instaUrl = RegExp(r'https?://\S*instagram\.com/\S+');

class _InstagramImportScreenState extends State<InstagramImportScreen> {
  final _url = TextEditingController();
  final _caption = TextEditingController();
  Recipe? _draft;
  bool _draftFromAi = false;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.sharedText;
    if (shared != null && shared.trim().isNotEmpty) {
      if (_urlOnly.hasMatch(shared)) {
        // Only a link was shared — Instagram doesn't share the caption text.
        _url.text = shared.trim();
      } else {
        _caption.text = shared;
        final m = _instaUrl.firstMatch(shared);
        if (m != null) _url.text = m.group(0)!;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reparse();
        // If a Gemini key is set, recognise the shared caption automatically.
        final app = context.read<AppState>();
        if (app.household.hasAiKey && _caption.text.trim().isNotEmpty) {
          _runAi();
        }
      });
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _reparse() {
    final text = _caption.text.trim();
    setState(() {
      _draftFromAi = false;
      _draft = text.isEmpty
          ? null
          : parseInstagramCaption(
              _caption.text,
              url: _url.text.trim().isEmpty ? null : _url.text.trim(),
            );
    });
  }

  Future<void> _runAi() async {
    final app = context.read<AppState>();
    final key = app.household.geminiApiKey;
    final caption = _caption.text.trim();
    if (caption.isEmpty) return;
    setState(() => _aiLoading = true);
    try {
      final recipe = await aiExtractRecipe(
        _caption.text,
        apiKey: key,
        url: _url.text.trim().isEmpty ? null : _url.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _draft = recipe;
        _draftFromAi = true;
      });
    } on AiImportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('KI-Import fehlgeschlagen: $e')));
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draft = _draft;
    final generic = widget.generic;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              generic ? 'Rezept einfügen' : 'Aus Instagram importieren')),
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
                    generic
                        ? 'Kopiere ein Rezept (z. B. aus Choosy, einem Blog '
                            'oder einer anderen App) und füge es unten ein. Die '
                            'App erkennt Zutaten, Mengen und Schritte – prüfe '
                            'die Vorschau und speichere.'
                        : 'Öffne das Reel/den Post in Instagram, kopiere die '
                            'Beschreibung und füge sie unten ein. Die App '
                            'erkennt Zutaten, Mengen und Schritte – prüfe die '
                            'Vorschau und speichere.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (!generic &&
              _caption.text.trim().isEmpty &&
              _url.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Nur der Link wurde geteilt – Instagram gibt die Beschreibung '
                'nicht mit. Tipp: In Instagram die Beschreibung antippen, Text '
                'markieren und über „Teilen" an Essensplan senden. Dann wird '
                'das Rezept automatisch erkannt.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            onChanged: (_) => _reparse(),
            decoration: InputDecoration(
              labelText: generic ? 'Link (optional)' : 'Instagram-Link (optional)',
              hintText: generic
                  ? 'https://…'
                  : 'https://www.instagram.com/reel/...',
              prefixIcon: const Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            onChanged: (_) => _reparse(),
            decoration: InputDecoration(
              labelText:
                  generic ? 'Rezept-Text einfügen' : 'Caption / Beschreibung einfügen',
              alignLabelWithHint: true,
            ),
            minLines: 6,
            maxLines: 16,
          ),
          const SizedBox(height: 16),
          _aiArea(context),
          const SizedBox(height: 12),
          if (draft != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _draftFromAi
                    ? '🤖 Von Gemini erkannt'
                    : '⚡ Schnell-Erkennung (offline)',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _draftFromAi ? scheme.primary : scheme.onSurfaceVariant,
                    ),
              ),
            ),
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

  Widget _aiArea(BuildContext context) {
    final hasKey = context.watch<AppState>().household.hasAiKey;
    final scheme = Theme.of(context).colorScheme;
    if (hasKey) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed:
              (_aiLoading || _caption.text.trim().isEmpty) ? null : _runAi,
          icon: _aiLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_aiLoading ? 'KI arbeitet…' : 'Mit KI erkennen (Gemini)'),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'KI-Import ist aus. Mit einem kostenlosen Gemini-Schlüssel '
                  'erkennt die App Rezepte automatisch und genauer (inkl. '
                  'Nährwerte).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('Schlüssel hinterlegen'),
            ),
          ),
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
