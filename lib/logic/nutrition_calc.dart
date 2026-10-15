import '../models/nutrition.dart';
import '../models/recipe.dart';
import '../models/week_plan.dart';

/// Aggregated nutrition + vegetable variety for a whole week.
class PlanAnalysis {
  /// Absolute nutrition eaten across the week (all people, all cooked meals).
  final Nutrition total;

  /// Number of recipe meals planned (freshly cooked + leftovers).
  final int recipeMeals;

  /// Number of "order"/takeout meals.
  final int orderMeals;

  /// persons × number of days — denominator for the daily average.
  final int personDays;

  /// Distinct vegetable/legume kinds eaten this week.
  final Set<String> produce;

  final int varietyTarget;
  final int persons;

  const PlanAnalysis({
    required this.total,
    required this.recipeMeals,
    required this.orderMeals,
    required this.personDays,
    required this.produce,
    required this.varietyTarget,
    required this.persons,
  });

  int get varietyCount => produce.length;
  bool get varietyReached => varietyCount >= varietyTarget;

  /// Average per person per day — the figure compared against daily targets.
  Nutrition get perPersonPerDay =>
      personDays == 0 ? Nutrition.zero : total.scale(1 / personDays);
}

/// Computes nutrition and variety for [plan] using the household [persons].
PlanAnalysis analysePlan(
  WeekPlan plan,
  Map<String, Recipe> recipesById, {
  required int persons,
  required int varietyTarget,
}) {
  var total = Nutrition.zero;
  final produce = <String>{};
  var recipeMeals = 0;
  var orderMeals = 0;

  for (final slot in plan.allSlots) {
    if (slot.type == SlotType.order) {
      orderMeals++;
      continue;
    }
    if (!slot.hasRecipe) continue;
    final recipe = recipesById[slot.recipeId];
    if (recipe == null) continue;
    recipeMeals++;
    // Everyone eats one serving of this meal.
    total = total + recipe.nutritionPerServing.scale(persons.toDouble());
    produce.addAll(recipe.produceKeys);
  }

  return PlanAnalysis(
    total: total,
    recipeMeals: recipeMeals,
    orderMeals: orderMeals,
    personDays: persons * plan.days.length,
    produce: produce,
    varietyTarget: varietyTarget,
    persons: persons,
  );
}
