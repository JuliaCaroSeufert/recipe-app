import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// A single meal slot rendered as a lively card. Presentational only — the
/// screen resolves the slot and decides what tapping does.
class MealCard extends StatelessWidget {
  final String mealLabel;
  final IconData mealIcon;
  final Color accent;
  final Widget leading;
  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final bool dim;
  final VoidCallback onTap;

  const MealCard({
    super.key,
    required this.mealLabel,
    required this.mealIcon,
    required this.accent,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badges = const [],
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(width: 84, height: 84, child: leading),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(mealIcon, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(mealLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: dim ? scheme.onSurfaceVariant : null,
                        height: 1.1,
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
