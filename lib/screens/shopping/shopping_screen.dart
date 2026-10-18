import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../logic/shopping_list.dart';
import '../../models/ingredient.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/dates.dart';
import '../../widgets/ui_kit.dart';

String _categoryEmoji(IngredientCategory c) => switch (c) {
      IngredientCategory.produce => '🥦',
      IngredientCategory.legumes => '🫘',
      IngredientCategory.dairy => '🧀',
      IngredientCategory.meatFish => '🍗',
      IngredientCategory.pantry => '🥫',
      IngredientCategory.spices => '🧂',
      IngredientCategory.frozen => '🧊',
      IngredientCategory.other => '🛒',
    };

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.currentPlan;
    final sections = app.currentShopping;

    final allItems = sections.expand((s) => s.items).toList();
    final checked = plan?.checked ?? const {};
    final done = allItems.where((i) => checked.contains(i.key)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufsliste'),
        actions: [
          if (sections.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Als Text kopieren',
              onPressed: () async {
                final text = shoppingListToText(sections,
                    title: plan == null
                        ? null
                        : weekRangeLabel(plan.startDate, plan.days.length));
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Einkaufsliste kopiert.')));
                }
              },
            ),
        ],
      ),
      body: plan == null
          ? const EmptyState(
              emoji: '🛒',
              title: 'Noch keine Liste',
              message:
                  'Plane zuerst eine Woche – dann entsteht hier automatisch '
                  'deine Einkaufsliste.')
          : sections.isEmpty
              ? const EmptyState(
                  emoji: '🎉',
                  title: 'Nichts einzukaufen',
                  message: 'Für diese Woche ist alles bestellt oder leer.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _ProgressCard(done: done, total: allItems.length),
                    const SizedBox(height: 14),
                    for (final section in sections) ...[
                      _CategorySection(
                        section: section,
                        checked: checked,
                        onToggle: app.toggleChecked,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : done / total;
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$done von $total erledigt',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(ratio >= 1 ? '✅' : '🛒', style: const TextStyle(fontSize: 28)),
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
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_categoryEmoji(section.category),
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(section.category.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      )),
            ],
          ),
          const SizedBox(height: 2),
          for (final item in section.items)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onToggle(item.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: Row(
                  children: [
                    _Check(checked: checked.contains(item.key)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          decoration: checked.contains(item.key)
                              ? TextDecoration.lineThrough
                              : null,
                          color: checked.contains(item.key)
                              ? scheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                    if (item.amountLabel.isNotEmpty)
                      Text(item.amountLabel,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool checked;
  const _Check({required this.checked});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? AppColors.green : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked ? AppColors.green : scheme.outline,
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
