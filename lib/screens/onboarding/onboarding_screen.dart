import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;
  int _persons = 2;

  @override
  void initState() {
    super.initState();
    _persons = context.read<AppState>().household.persons;
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final app = context.read<AppState>();
    await app.saveHousehold(
        app.household.copyWith(persons: _persons, onboarded: true));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const last = 2;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _Slide(
                    emoji: '🥗',
                    title: 'Willkommen bei\nEssensplan',
                    text:
                        'Plane deine Woche für Mittag- und Abendessen – schnell, '
                        'ausgewogen und mit viel Gemüse. Ganz ohne Stress.',
                  ),
                  const _Slide(
                    emoji: '✨',
                    title: 'In Minuten geplant',
                    text:
                        'Lass dir eine ganze Woche vorschlagen oder blättere '
                        'Rezept-Karten durch. Batch-Cooking, Bestell-Tage und '
                        'deine Abneigungen werden berücksichtigt.',
                  ),
                  _SetupSlide(
                    persons: _persons,
                    onChanged: (v) => setState(() => _persons = v),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i <= last; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () {
                  if (_page >= last) {
                    _finish();
                  } else {
                    _pc.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut);
                  }
                },
                child: Text(_page >= last ? 'Los geht\'s 🎉' : 'Weiter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final String emoji;
  final String title;
  final String text;
  const _Slide(
      {required this.emoji, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 60)),
          ),
          const SizedBox(height: 28),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }
}

class _SetupSlide extends StatelessWidget {
  final int persons;
  final ValueChanged<int> onChanged;
  const _SetupSlide({required this.persons, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👩‍🍳', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 20),
          Text('Für wie viele kochst du?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Du kannst das später jederzeit ändern.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: persons > 1 ? () => onChanged(persons - 1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('$persons',
                    style: Theme.of(context).textTheme.displaySmall),
              ),
              IconButton.filledTonal(
                onPressed: persons < 12 ? () => onChanged(persons + 1) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(persons == 1 ? 'Person' : 'Personen',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
