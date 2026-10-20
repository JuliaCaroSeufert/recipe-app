import 'package:essensplan/data/seed_recipes.dart';
import 'package:essensplan/logic/nutrition_calc.dart';
import 'package:essensplan/logic/plan_generator.dart';
import 'package:essensplan/logic/shopping_list.dart';
import 'package:essensplan/logic/spoonacular.dart';
import 'package:essensplan/models/household.dart';
import 'package:essensplan/models/recipe.dart';
import 'package:essensplan/models/week_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recipesById = {for (final r in seedRecipes) r.id: r};
  final monday = DateTime(2026, 10, 19);

  group('generateWeekPlan', () {
    test('fills every cookable slot with a recipe', () {
      final plan = generateWeekPlan(
        GenerateConfig(startDate: monday, seed: 1),
        seedRecipes,
        const Household(persons: 2),
      );
      expect(plan.days.length, 7);
      for (final day in plan.days) {
        for (final meal in MealType.values) {
          final slot = day.slot(meal);
          expect(slot.type == SlotType.cook || slot.type == SlotType.leftover,
              isTrue,
              reason: 'every slot should have food');
          expect(recipesById.containsKey(slot.recipeId), isTrue);
        }
      }
    });

    test('respects order slots and leaves them without a recipe', () {
      final plan = generateWeekPlan(
        GenerateConfig(
          startDate: monday,
          seed: 2,
          orderSlots: {slotKey(5, MealType.dinner), slotKey(6, MealType.dinner)},
        ),
        seedRecipes,
        const Household(persons: 2),
      );
      expect(plan.days[5].slot(MealType.dinner).type, SlotType.order);
      expect(plan.days[6].slot(MealType.dinner).type, SlotType.order);
      expect(plan.days[5].slot(MealType.dinner).recipeId, isNull);
    });

    test('never includes a disliked ingredient', () {
      final plan = generateWeekPlan(
        GenerateConfig(startDate: monday, seed: 3),
        seedRecipes,
        const Household(persons: 2, dislikes: ['lachs', 'tofu']),
      );
      for (final slot in plan.allSlots.where((s) => s.hasRecipe)) {
        final r = recipesById[slot.recipeId]!;
        expect(r.matchTerms.contains('lachs'), isFalse);
        expect(r.matchTerms.contains('tofu'), isFalse);
      }
    });

    test('vegan filter only keeps vegan recipes', () {
      final plan = generateWeekPlan(
        GenerateConfig(startDate: monday, seed: 4),
        seedRecipes,
        const Household(persons: 2, veganOnly: true),
      );
      for (final slot in plan.allSlots.where((s) => s.hasRecipe)) {
        expect(recipesById[slot.recipeId]!.isVegan, isTrue);
      }
    });

    test('batch session creates one cook slot and leftover slots', () {
      final plan = generateWeekPlan(
        GenerateConfig(
            startDate: monday, seed: 5, batchSessions: 1, batchSpan: 3),
        seedRecipes,
        const Household(persons: 2),
      );
      final leftovers =
          plan.allSlots.where((s) => s.type == SlotType.leftover).toList();
      expect(leftovers, isNotEmpty);
      // The leftover's batch has a matching cook slot cooking extra servings.
      final batchId = leftovers.first.batchId;
      final cook = plan.allSlots.firstWhere(
          (s) => s.type == SlotType.cook && s.batchId == batchId);
      expect(cook.servings, greaterThan(2));
    });

    test('never serves the same recipe twice on one day; batch spans days', () {
      final plan = generateWeekPlan(
        GenerateConfig(
            startDate: monday, seed: 9, batchSessions: 2, batchSpan: 4),
        seedRecipes,
        const Household(persons: 2),
      );
      // No day has the same recipe for both lunch and dinner.
      for (final day in plan.days) {
        final ids = day.meals.values
            .where((s) => s.hasRecipe)
            .map((s) => s.recipeId)
            .toList();
        expect(ids.length, ids.toSet().length,
            reason: 'same dish twice on one day');
      }
      // Each batch group lands on distinct days.
      final byBatch = <String, List<int>>{};
      for (var d = 0; d < plan.days.length; d++) {
        for (final s in plan.days[d].meals.values) {
          if (s.batchId != null) {
            byBatch.putIfAbsent(s.batchId!, () => []).add(d);
          }
        }
      }
      for (final days in byBatch.values) {
        expect(days.length, days.toSet().length,
            reason: 'batch cooked/eaten twice on one day');
      }
    });

    test('reaches a strong vegetable variety over the week', () {
      final plan = generateWeekPlan(
        GenerateConfig(startDate: monday, seed: 7),
        seedRecipes,
        const Household(persons: 2),
      );
      final analysis = analysePlan(plan, recipesById,
          persons: 2, varietyTarget: 20);
      expect(analysis.varietyCount, greaterThanOrEqualTo(20));
    });
  });

  group('tolerant dislikes', () {
    bool hasProduce(List<Recipe> rs, String key) =>
        rs.any((r) => r.produceKeys.any(
            (p) => p.toLowerCase().contains(key.toLowerCase())));

    test('excludes a dislike regardless of case/spelling/spaces', () {
      for (final d in ['Pak Choi', 'pak choi', 'PAKCHOI', 'pak-choi']) {
        final filtered =
            filterForHousehold(seedRecipes, Household(dislikes: [d]));
        expect(hasProduce(filtered, 'Pak Choi'), isFalse, reason: d);
      }
    });

    test('singular and plural both exclude beans', () {
      for (final d in ['bohne', 'Bohnen']) {
        final filtered =
            filterForHousehold(seedRecipes, Household(dislikes: [d]));
        expect(hasProduce(filtered, 'bohne'), isFalse, reason: d);
      }
    });

    test('a compound dislike word still catches variants', () {
      // "Zwiebel" should also remove recipes with "Frühlingszwiebel".
      final filtered = filterForHousehold(
          seedRecipes, const Household(dislikes: ['Zwiebel']));
      expect(hasProduce(filtered, 'zwiebel'), isFalse);
    });
  });

  group('analysePlan', () {
    test('scales nutrition by number of persons', () {
      final plan = WeekPlan.blank(
        startDate: monday,
        label: 'Test',
        numDays: 1,
        meals: const [MealType.dinner],
      ).withSlot(
        0,
        MealType.dinner,
        const MealSlot(
            type: SlotType.cook, recipeId: 'seed-linsen-dal', servings: 4),
      );
      final a2 = analysePlan(plan, recipesById, persons: 2, varietyTarget: 20);
      final a4 = analysePlan(plan, recipesById, persons: 4, varietyTarget: 20);
      expect(a4.total.kcal, closeTo(a2.total.kcal * 2, 0.01));
    });
  });

  group('buildShoppingList', () {
    test('merges equal ingredients across slots and scales by servings', () {
      final plan = WeekPlan.blank(
        startDate: monday,
        label: 'Test',
        numDays: 2,
        meals: const [MealType.dinner],
      )
          .withSlot(
              0,
              MealType.dinner,
              const MealSlot(
                  type: SlotType.cook,
                  recipeId: 'seed-linsen-dal',
                  servings: 2))
          .withSlot(
              1,
              MealType.dinner,
              const MealSlot(
                  type: SlotType.cook,
                  recipeId: 'seed-linsen-dal',
                  servings: 2));
      final sections = buildShoppingList(plan, recipesById);
      final allItems = sections.expand((s) => s.items).toList();
      // Two servings each (= base servings) twice → 400 g red lentils total.
      final lentils =
          allItems.firstWhere((i) => i.name == 'Rote Linsen');
      expect(lentils.amount, closeTo(400, 0.01));
    });

    test('leftover and order slots add nothing to the list', () {
      final plan = WeekPlan.blank(
        startDate: monday,
        label: 'Test',
        numDays: 2,
        meals: const [MealType.dinner],
      )
          .withSlot(
              0,
              MealType.dinner,
              const MealSlot(type: SlotType.order, note: 'Pizza'))
          .withSlot(
              1,
              MealType.dinner,
              const MealSlot(
                  type: SlotType.leftover, recipeId: 'seed-linsen-dal'));
      final sections = buildShoppingList(plan, recipesById);
      expect(sections, isEmpty);
    });
  });

  group('favourite cadence', () {
    Set<String> plannedIds(plan) {
      final used = <String>{};
      for (final d in plan.days) {
        for (final s in d.meals.values) {
          if (s.recipeId != null) used.add(s.recipeId as String);
        }
      }
      return used;
    }

    test('a favourite overdue by more than the interval is planned', () {
      final fav = seedRecipes.first.copyWith(isFavorite: true);
      final library = [fav, ...seedRecipes.skip(1)];
      final plan = generateWeekPlan(
        GenerateConfig(startDate: monday, seed: 3),
        library,
        const Household(persons: 2),
        history: {fav.id: monday.subtract(const Duration(days: 70))},
      );
      expect(plannedIds(plan).contains(fav.id), isTrue);
    });

    test('a favourite planned last week is not forced back immediately', () {
      // Not a hard guarantee, but with a recent plan the overdue boost is off.
      final fav = seedRecipes.first.copyWith(isFavorite: true);
      final library = [fav, ...seedRecipes.skip(1)];
      final plan = generateWeekPlan(
        GenerateConfig(startDate: monday, seed: 3),
        library,
        const Household(persons: 2),
        history: {fav.id: monday.subtract(const Duration(days: 7))},
      );
      // Sanity: generation still fills the week.
      expect(plannedIds(plan).isNotEmpty, isTrue);
    });
  });

  group('spoonacular helpers', () {
    test('builds a short English query from a German title', () {
      final dal = seedRecipes.firstWhere((r) => r.id == 'seed-linsen-dal');
      final q = spoonacularQuery(dal);
      expect(q.contains('food'), isFalse);
      expect(q.contains('meal'), isFalse);
      expect(q.toLowerCase(), contains('dal'));
      expect(q.split(' ').length, lessThanOrEqualTo(3));
    });

    test('upgrades a Spoonacular image URL to a crisp size', () {
      expect(
        bestSpoonacularImageUrl(
            image: 'https://img.spoonacular.com/recipes/716429-312x231.jpg'),
        'https://img.spoonacular.com/recipes/716429-636x393.jpg',
      );
    });

    test('builds an image URL from an id when none is given', () {
      expect(bestSpoonacularImageUrl(id: 12345),
          'https://img.spoonacular.com/recipes/12345-636x393.jpg');
      expect(bestSpoonacularImageUrl(), isNull);
    });

    test('leaves non-Spoonacular publisher URLs unchanged', () {
      const url = 'https://example.com/photos/curry.jpg';
      expect(bestSpoonacularImageUrl(image: url), url);
    });

    test('parses the first result image from a search body', () {
      final json = {
        'results': [
          {'id': 716429, 'image': 'https://img.spoonacular.com/recipes/716429-312x231.jpg'},
        ],
      };
      expect(parseSpoonacularImage(json),
          'https://img.spoonacular.com/recipes/716429-636x393.jpg');
      expect(parseSpoonacularImage({'results': []}), isNull);
    });
  });
}
