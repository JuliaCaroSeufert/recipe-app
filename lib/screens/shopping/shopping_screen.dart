import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../logic/shopping_list.dart';
import '../../state/app_state.dart';
import '../../utils/dates.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.currentPlan;
    final sections = app.currentShopping;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufsliste'),
        actions: [
          if (sections.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Als Text kopieren',
              onPressed: () async {
                final text = shoppingListToText(
                  sections,
                  title: plan == null
                      ? null
                      : weekRangeLabel(plan.startDate, plan.days.length),
                );
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Einkaufsliste kopiert.')),
                  );
                }
              },
            ),
        ],
      ),
      body: plan == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Plane zuerst eine Woche – dann entsteht hier automatisch '
                  'deine Einkaufsliste.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : sections.isEmpty
              ? const Center(child: Text('Nichts einzukaufen (alles bestellt?).'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
                  children: [
                    for (final section in sections)
                      _CategorySection(
                        section: section,
                        checked: plan.checked,
                        onToggle: app.toggleChecked,
                      ),
                  ],
                ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final ShoppingSection section;
  final Set<String> checked;
  final Future<void> Function(String key) onToggle;

  const _CategorySection({
    required this.section,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Text(section.category.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      )),
            ),
            for (final item in section.items)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: checked.contains(item.key),
                onChanged: (_) => onToggle(item.key),
                title: Text(
                  item.name,
                  style: TextStyle(
                    decoration: checked.contains(item.key)
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                secondary: item.amountLabel.isEmpty
                    ? null
                    : Text(item.amountLabel,
                        style: Theme.of(context).textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
