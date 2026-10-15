import 'package:uuid/uuid.dart';

import 'recipe.dart';

const _uuid = Uuid();

enum SlotType {
  /// A recipe freshly cooked in this slot.
  cook,

  /// Leftovers from a batch cooked in another slot (same [MealSlot.batchId]).
  leftover,

  /// Ordered / eaten out — no cooking, no shopping.
  order,

  /// Nothing planned.
  empty,
}

/// One meal (lunch or dinner) on one day.
class MealSlot {
  final SlotType type;
  final String? recipeId;

  /// Servings cooked in this slot. For a [SlotType.cook] slot this is the
  /// batch size (persons × number of meals it covers); for everything else 0.
  final int servings;

  /// Links a batch-cook slot with the leftover slots it feeds.
  final String? batchId;

  /// Free note, e.g. the restaurant for an [SlotType.order] slot.
  final String? note;

  const MealSlot({
    this.type = SlotType.empty,
    this.recipeId,
    this.servings = 0,
    this.batchId,
    this.note,
  });

  const MealSlot.empty() : this();

  bool get isEmpty => type == SlotType.empty;
  bool get hasRecipe =>
      recipeId != null && (type == SlotType.cook || type == SlotType.leftover);

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'recipeId': recipeId,
        'servings': servings,
        'batchId': batchId,
        'note': note,
      };

  factory MealSlot.fromJson(Map<String, dynamic> j) => MealSlot(
        type: SlotType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => SlotType.empty,
        ),
        recipeId: j['recipeId'] as String?,
        servings: (j['servings'] as num?)?.toInt() ?? 0,
        batchId: j['batchId'] as String?,
        note: j['note'] as String?,
      );
}

/// One day with its meal slots keyed by [MealType].
class DayPlan {
  final DateTime date;
  final Map<MealType, MealSlot> meals;

  DayPlan({required this.date, Map<MealType, MealSlot>? meals})
      : meals = meals ?? {};

  MealSlot slot(MealType m) => meals[m] ?? const MealSlot.empty();

  DayPlan withSlot(MealType m, MealSlot slot) =>
      DayPlan(date: date, meals: {...meals, m: slot});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'meals': meals.map((k, v) => MapEntry(k.name, v.toJson())),
      };

  factory DayPlan.fromJson(Map<String, dynamic> j) {
    final raw = (j['meals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final meals = <MealType, MealSlot>{};
    raw.forEach((k, v) {
      final mt = MealType.values.firstWhere(
        (m) => m.name == k,
        orElse: () => MealType.dinner,
      );
      meals[mt] = MealSlot.fromJson((v as Map).cast<String, dynamic>());
    });
    return DayPlan(
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      meals: meals,
    );
  }
}

/// A full weekly meal plan.
class WeekPlan {
  final String id;
  final String label;
  final DateTime startDate;
  final List<DayPlan> days;

  /// Shopping-list items the user ticked off, by item key.
  final Set<String> checked;
  final bool archived;
  final DateTime createdAt;

  WeekPlan({
    required this.id,
    required this.label,
    required this.startDate,
    required this.days,
    Set<String>? checked,
    this.archived = false,
    required this.createdAt,
  }) : checked = checked ?? {};

  Iterable<MealSlot> get allSlots =>
      days.expand((d) => d.meals.values);

  /// Slots that are actually cooked (drive shopping + nutrition totals).
  Iterable<MealSlot> get cookSlots =>
      allSlots.where((s) => s.type == SlotType.cook);

  WeekPlan copyWith({
    String? label,
    List<DayPlan>? days,
    Set<String>? checked,
    bool? archived,
  }) =>
      WeekPlan(
        id: id,
        label: label ?? this.label,
        startDate: startDate,
        days: days ?? this.days,
        checked: checked ?? this.checked,
        archived: archived ?? this.archived,
        createdAt: createdAt,
      );

  /// Replace a single slot and return a new plan.
  WeekPlan withSlot(int dayIndex, MealType meal, MealSlot slot) {
    final newDays = [...days];
    newDays[dayIndex] = newDays[dayIndex].withSlot(meal, slot);
    return copyWith(days: newDays);
  }

  /// Recycle this week onto a new start date (keeps recipes, shifts dates,
  /// clears the shopping ticks). Used by the archive.
  WeekPlan recycleTo(DateTime newStart, {String? label}) {
    final shifted = <DayPlan>[];
    for (var i = 0; i < days.length; i++) {
      shifted.add(DayPlan(
        date: DateTime(newStart.year, newStart.month, newStart.day)
            .add(Duration(days: i)),
        meals: {
          for (final e in days[i].meals.entries) e.key: e.value,
        },
      ));
    }
    return WeekPlan(
      id: _uuid.v4(),
      label: label ?? this.label,
      startDate: DateTime(newStart.year, newStart.month, newStart.day),
      days: shifted,
      archived: false,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'startDate': startDate.toIso8601String(),
        'days': days.map((d) => d.toJson()).toList(),
        'checked': checked.toList(),
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WeekPlan.fromJson(Map<String, dynamic> j) => WeekPlan(
        id: j['id'] as String,
        label: (j['label'] as String?) ?? 'Woche',
        startDate:
            DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
        days: ((j['days'] as List?) ?? const [])
            .map((e) => DayPlan.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        checked: ((j['checked'] as List?) ?? const []).cast<String>().toSet(),
        archived: (j['archived'] as bool?) ?? false,
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  /// A blank 7-day week with lunch + dinner slots for every day.
  factory WeekPlan.blank({
    required DateTime startDate,
    required String label,
    int numDays = 7,
    List<MealType> meals = const [MealType.lunch, MealType.dinner],
  }) {
    final base = DateTime(startDate.year, startDate.month, startDate.day);
    return WeekPlan(
      id: _uuid.v4(),
      label: label,
      startDate: base,
      createdAt: DateTime.now(),
      days: [
        for (var i = 0; i < numDays; i++)
          DayPlan(
            date: base.add(Duration(days: i)),
            meals: {for (final m in meals) m: const MealSlot.empty()},
          ),
      ],
    );
  }
}
