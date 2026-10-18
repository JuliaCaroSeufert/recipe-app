import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// A single meal slot rendered as a lively card. Presentational only — the
/// screen resolves the slot and decides what tapping does.
class MealCard extends StatelessWidget {
  final String mealLabel;
  final IconData mealIcon;
  final Color accent;
  final String emoji;
  final String seed;
  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final bool empty;
  final VoidCallback onTap;

  const MealCard({
    super.key,
    required this.mealLabel,
    required this.mealIcon,
    required this.accent,
    required this.emoji,
    required this.seed,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badges = const [],
    this.empty = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (empty)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add, color: scheme.onSurfaceVariant),
            )
          else
            EmojiTile(emoji: emoji, seed: seed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(mealIcon, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text(mealLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            )),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: empty ? scheme.onSurfaceVariant : null,
                      ),
                ),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: badges),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
