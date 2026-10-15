import 'package:flutter/material.dart';

import '../../logic/instagram_parse.dart';
import 'recipe_edit.dart';

/// Import a recipe from Instagram by pasting the post/reel link and its
/// caption text. Automatic fetching of other creators' posts isn't possible
/// (and would breach Instagram's terms), so the user pastes the text and we
/// turn it into a draft they review.
class InstagramImportScreen extends StatefulWidget {
  const InstagramImportScreen({super.key});

  @override
  State<InstagramImportScreen> createState() => _InstagramImportScreenState();
}

class _InstagramImportScreenState extends State<InstagramImportScreen> {
  final _url = TextEditingController();
  final _caption = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _import() {
    final draft = parseInstagramCaption(
      _caption.text,
      url: _url.text.trim().isEmpty ? null : _url.text.trim(),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RecipeEditScreen(initial: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    'Beschreibung (Caption) und füge sie unten ein. Die App '
                    'erkennt Zutaten und Schritte automatisch – du kannst '
                    'danach alles anpassen.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Instagram-Link (optional)',
              hintText: 'https://www.instagram.com/reel/...',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            decoration: const InputDecoration(
              labelText: 'Caption / Beschreibung einfügen',
              alignLabelWithHint: true,
            ),
            minLines: 8,
            maxLines: 20,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _import,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Rezept erkennen'),
          ),
        ],
      ),
    );
  }
}
