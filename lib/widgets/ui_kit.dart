import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Small rounded label with an optional leading icon — for time, kcal, badges.
class Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;

  const Pill(this.label, {super.key, this.icon, this.color, this.background});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 5, 10, 5),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Soft pastel tag pill (Protein, Vegan, Schnell …) in the style of modern
/// recipe apps — a light tinted background with matching dark text, fully
/// rounded. The colour is picked deterministically from the label so the same
/// tag always looks the same and a row of tags is pleasantly multi-coloured.
class TagPill extends StatelessWidget {
  final String label;
  const TagPill(this.label, {super.key});

  // (background, text) pastel pairs.
  static const List<(Color, Color)> _pairs = [
    (Color(0xFFEDEBFF), Color(0xFF5B4BD6)), // lavender
    (Color(0xFFDBF3EC), Color(0xFF0E9384)), // mint
    (Color(0xFFE5EDFF), Color(0xFF3B5BDB)), // blue
    (Color(0xFFFCE3F0), Color(0xFFC03B86)), // pink
    (Color(0xFFFFEAD6), Color(0xFFC2560F)), // peach
    (Color(0xFFE9F3D4), Color(0xFF59820F)), // pistachio
  ];

  @override
  Widget build(BuildContext context) {
    var h = 0;
    for (final c in label.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final (bg, fg) = _pairs[h % _pairs.length];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? bg.withValues(alpha: 0.18) : bg,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: dark ? bg : fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// A rounded, colour-tinted square holding a big emoji — our stand-in for food
/// photography. Lively and consistent.
class EmojiTile extends StatelessWidget {
  final String emoji;
  final String seed;
  final double size;
  final double radius;

  const EmojiTile({
    super.key,
    required this.emoji,
    required this.seed,
    this.size = 56,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark
        ? AppColors.tileFor(seed).withValues(alpha: 0.22)
        : AppColors.tileFor(seed);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Section header with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 6, 4, 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A circular progress ring with a value in the middle. Used for the nutrition
/// and vegetable-variety at-a-glance stats.
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double size;
  final double stroke;
  final String centerText;
  final String label;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.centerText,
    required this.label,
    this.size = 86,
    this.stroke = 9,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1),
          color: color,
          track: scheme.surfaceContainerHighest,
          stroke: stroke,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                      )),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, trackPaint);
    const start = -math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      2 * math.pi * value,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Friendly empty state with a big emoji and an optional call to action.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Soft-shadow wrapper that matches the card look but works outside [Card].
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ??
            (dark ? AppColors.darkCard : AppColors.card),
        borderRadius: BorderRadius.circular(22),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: content,
    );
  }
}
