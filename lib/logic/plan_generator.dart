import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/household.dart';
import '../models/nutrition.dart';
import '../models/recipe.dart';
import '../models/week_plan.dart';
import 'text_match.dart';

const _uuid = Uuid();

String slotKey(int dayIndex, MealType meal) => '$dayIndex:${meal.name}';

/// Options chosen in the "Woche planen" sheet.
class GenerateConfig {
  final DateTime startDate;
  final int numDays;
  final List<MealType> meals;

  /// Slots (keyed by [slotKey]) the user wants to order/eat out instead.
  final Set<String> orderSlots;

  /// Slots to leave open (not planned at all).
  final Set<String> emptySlots;

  /// How many batch-cook sessions to create (cook once, eat several times).
  final int batchSessions;

  /// How many meals one batch session should cover.
  final int batchSpan;

  final String label;
  final int? seed;

  const GenerateConfig({
    required this.startDate,
    this.numDays = 7,
    this.meals = const [MealType.lunch, MealType.dinner],
    this.orderSlots = const {},
    this.emptySlots = const {},
    this.batchSessions = 0,
    this.batchSpan = 3,
    this.label = 'Woche',
    this.seed,
  });
}

/// Nutrients the optimiser actively tries to meet (commonly under-eaten ones).
/// kcal / carbs / fat are intentionally left out — we don't maximise those.
const List<String> _focusNutrients = [
  'protein',
  'fiber',
  'iron',
  'calcium',
  'magnesium',
  'potassium',
  'zinc',
  'vitaminC',
  'vitaminA',
  'folate',
];

/// Returns the recipes left after applying the household diet + dislikes.
/// Dislikes are matched tolerantly (case, umlauts, spelling, plural) so adding
/// "Pak Choi" also catches "pak choi", "pakchoi" etc.
List<Recipe> filterForHousehold(Iterable<Recipe> recipes, Household h) {
  final dislikeForms = [
    for (final d in h.dislikes)
      if (expandTerm(d).isNotEmpty) expandTerm(d),
  ];
  return recipes.where((r) {
    if (h.veganOnly && !r.isVegan) return false;
    if (h.vegetarianOnly && !r.isVegetarian) return false;
    if (dislikeForms.isNotEmpty) {
      final hay = <String>{};
      for (final term in r.matchTerms) {
        hay.addAll(expandTerm(term));
      }
      for (final needles in dislikeForms) {
        if (matchesAny(hay, needles)) return false;
      }
    }
    return true;
  }).toList();
}

/// Builds a weekly plan that favours vegetable variety and fills common
/// nutrient gaps, while honouring batch-cook and order/eat-out choices.
WeekPlan generateWeekPlan(
  GenerateConfig config,
  List<Recipe> library,
  Household household,
) {
  final rng = Random(config.seed ?? DateTime.now().millisecondsSinceEpoch);
  final persons = household.persons;

  // Mutable day structure.
  final base = DateTime(
      config.startDate.year, config.startDate.month, config.startDate.day);
  final dayMeals = <int, Map<MealType, MealSlot>>{};
  for (var d = 0; d < config.numDays; d++) {
    dayMeals[d] = {for (final m in config.meals) m: const MealSlot.empty()};
  }

  // Apply order / empty choices first.
  for (var d = 0; d < config.numDays; d++) {
    for (final m in config.meals) {
      final key = slotKey(d, m);
      if (config.orderSlots.contains(key)) {
        dayMeals[d]![m] = const MealSlot(type: SlotType.order);
      } else if (config.emptySlots.contains(key)) {
        dayMeals[d]![m] = const MealSlot.empty();
      }
    }
  }

  // The list of cookable slot positions (in chronological order).
  final cookPositions = <(int, MealType)>[];
  for (var d = 0; d < config.numDays; d++) {
    for (final m in config.meals) {
      final slot = dayMeals[d]![m]!;
      if (slot.type == SlotType.empty &&
          !config.orderSlots.contains(slotKey(d, m)) &&
          !config.emptySlots.contains(slotKey(d, m))) {
        cookPositions.add((d, m));
      }
    }
  }

  final candidates = filterForHousehold(library, household);
  if (candidates.isEmpty) {
    return _assemble(config, base, dayMeals);
  }

  final used = <String>{};
  final produceSoFar = <String>{};
  var nutritionSoFar = Nutrition.zero;
  final filled = <int>{}; // indices into cookPositions already filled

  // Weekly nutrient targets (absolute).
  final weeklyTarget = <String, double>{
    for (final n in kNutrients)
      n.key: n.dailyPerPerson * persons * config.numDays,
  };

  bool suits(Recipe r, MealType m) => r.suitableFor.contains(m);

  // --- 1) Batch-cook sessions -------------------------------------------
  final batchPool = candidates.where((r) => r.batchFriendly).toList()
    ..shuffle(rng)
    // Favourites first, so a favourite batch dish is preferred.
    ..sort((a, b) =>
        (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0));
  var sessionsMade = 0;
  for (final recipe in batchPool) {
    if (sessionsMade >= config.batchSessions) break;
    // Spread a batch across DISTINCT days (at most one meal per day), so the
    // same dish never lands twice on one day. Takes the earliest available
    // days, up to batchSpan days.
    final firstFreePerDay = <int, int>{}; // day -> cookPositions index
    for (var i = 0; i < cookPositions.length; i++) {
      if (filled.contains(i)) continue;
      final (day, meal) = cookPositions[i];
      if (!suits(recipe, meal)) continue;
      firstFreePerDay.putIfAbsent(day, () => i);
    }
    final days = firstFreePerDay.keys.toList()..sort();
    if (days.length < 2) continue; // need at least two days to batch
    final span =
        days.length < config.batchSpan ? days.length : config.batchSpan;
    final run = [for (final d in days.take(span)) firstFreePerDay[d]!];
    final batchId = _uuid.v4();
    for (var k = 0; k < run.length; k++) {
      final posIndex = run[k];
      final (day, meal) = cookPositions[posIndex];
      if (k == 0) {
        dayMeals[day]![meal] = MealSlot(
          type: SlotType.cook,
          recipeId: recipe.id,
          servings: persons * span,
          batchId: batchId,
        );
      } else {
        dayMeals[day]![meal] = MealSlot(
          type: SlotType.leftover,
          recipeId: recipe.id,
          batchId: batchId,
        );
      }
      filled.add(posIndex);
    }
    used.add(recipe.id);
    produceSoFar.addAll(recipe.produceKeys);
    // Count nutrition for every meal the batch covers.
    nutritionSoFar = nutritionSoFar +
        recipe.nutritionPerServing.scale((persons * span).toDouble());
    sessionsMade++;
  }

  // --- 2) Greedy fill of the remaining slots ----------------------------
  for (var i = 0; i < cookPositions.length; i++) {
    if (filled.contains(i)) continue;
    final (day, meal) = cookPositions[i];

    Recipe? best;
    var bestScore = double.negativeInfinity;
    for (final r in candidates) {
      if (!suits(r, meal)) continue;
      final score = _score(
        r,
        produceSoFar: produceSoFar,
        nutritionSoFar: nutritionSoFar,
        weeklyTarget: weeklyTarget,
        persons: persons,
        alreadyUsed: used.contains(r.id),
        jitter: rng.nextDouble() * 0.5,
      );
      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    best ??= candidates[rng.nextInt(candidates.length)];

    dayMeals[day]![meal] = MealSlot(
      type: SlotType.cook,
      recipeId: best.id,
      servings: persons,
    );
    filled.add(i);
    used.add(best.id);
    produceSoFar.addAll(best.produceKeys);
    nutritionSoFar = nutritionSoFar +
        best.nutritionPerServing.scale(persons.toDouble());
  }

  return _assemble(config, base, dayMeals);
}

double _score(
  Recipe r, {
  required Set<String> produceSoFar,
  required Nutrition nutritionSoFar,
  required Map<String, double> weeklyTarget,
  required int persons,
  required bool alreadyUsed,
  required double jitter,
}) {
  // Variety: strongly reward produce we don't have yet.
  final newProduce =
      r.produceKeys.where((p) => !produceSoFar.contains(p)).length;
  final varietyScore = newProduce * 3.0;

  // Nutrition: reward filling still-open deficits in focus nutrients.
  var nutritionScore = 0.0;
  for (final key in _focusNutrients) {
    final target = weeklyTarget[key] ?? 0;
    if (target <= 0) continue;
    final have = nutritionSoFar.byKey(key);
    final need = (target - have).clamp(0, target);
    if (need <= 0) continue;
    final contribution = r.nutritionPerServing.byKey(key) * persons;
    final filled = contribution.clamp(0, need.toDouble());
    nutritionScore += filled / target; // 0..1 per nutrient
  }
  nutritionScore = nutritionScore / _focusNutrients.length * 6.0;

  // Favourites surface noticeably more often in the weekly plan.
  final favoriteBonus = r.isFavorite ? 2.5 : 0.0;

  final repeatPenalty = alreadyUsed ? -100.0 : 0.0;
  return varietyScore + nutritionScore + favoriteBonus + repeatPenalty + jitter;
}

WeekPlan _assemble(
  GenerateConfig config,
  DateTime base,
  Map<int, Map<MealType, MealSlot>> dayMeals,
) {
  return WeekPlan(
    id: _uuid.v4(),
    label: config.label,
    startDate: base,
    createdAt: DateTime.now(),
    days: [
      for (var d = 0; d < config.numDays; d++)
        DayPlan(
          date: base.add(Duration(days: d)),
          meals: dayMeals[d] ?? {},
        ),
    ],
  );
}
