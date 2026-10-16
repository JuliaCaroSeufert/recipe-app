import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/household.dart';
import '../models/recipe.dart';
import '../models/week_plan.dart';
import 'seed_recipes.dart';

/// Cross-platform local persistence (Android, iOS and Web) via
/// shared_preferences. Entities are stored as JSON strings — simple, robust
/// and enough for a single-user offline app. On the web the data lives in the
/// browser's local storage, which is what makes the hosted preview work.
class Repository {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _kRecipes = 'recipes';
  static const _kPlans = 'plans';
  static const _kHousehold = 'household';
  static const _kCurrent = 'currentPlanId';
  static const _kSeeded = 'seeded_v1';

  Future<void> _ensureSeed() async {
    final p = await _p;
    if (p.getBool(_kSeeded) == true) return;
    if (!p.containsKey(_kRecipes)) {
      await p.setString(
        _kRecipes,
        jsonEncode([for (final r in seedRecipes) r.toJson()]),
      );
    }
    await p.setBool(_kSeeded, true);
  }

  // --- Recipes -----------------------------------------------------------
  Future<List<Recipe>> loadRecipes() async {
    await _ensureSeed();
    final raw = (await _p).getString(_kRecipes);
    if (raw == null) return [];
    return [
      for (final e in jsonDecode(raw) as List)
        Recipe.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  Future<void> _saveRecipes(List<Recipe> list) async {
    await (await _p)
        .setString(_kRecipes, jsonEncode([for (final r in list) r.toJson()]));
  }

  Future<void> saveRecipe(Recipe recipe) async {
    final list = await loadRecipes();
    final idx = list.indexWhere((r) => r.id == recipe.id);
    if (idx >= 0) {
      list[idx] = recipe;
    } else {
      list.add(recipe);
    }
    await _saveRecipes(list);
  }

  Future<void> deleteRecipe(String id) async {
    final list = await loadRecipes()
      ..removeWhere((r) => r.id == id);
    await _saveRecipes(list);
  }

  /// Re-adds the built-in recipes (keeps the user's own ones).
  Future<void> restoreSeedRecipes() async {
    final list = await loadRecipes();
    final byId = {for (final r in list) r.id: r};
    for (final s in seedRecipes) {
      byId[s.id] = s;
    }
    await _saveRecipes(byId.values.toList());
  }

  // --- Plans -------------------------------------------------------------
  Future<List<WeekPlan>> loadPlans() async {
    final raw = (await _p).getString(_kPlans);
    if (raw == null) return [];
    final list = [
      for (final e in jsonDecode(raw) as List)
        WeekPlan.fromJson((e as Map).cast<String, dynamic>()),
    ];
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  Future<void> _savePlans(List<WeekPlan> list) async {
    await (await _p)
        .setString(_kPlans, jsonEncode([for (final p in list) p.toJson()]));
  }

  Future<void> savePlan(WeekPlan plan) async {
    final list = await loadPlans();
    final idx = list.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      list[idx] = plan;
    } else {
      list.add(plan);
    }
    await _savePlans(list);
  }

  Future<void> deletePlan(String id) async {
    final list = await loadPlans()
      ..removeWhere((p) => p.id == id);
    await _savePlans(list);
  }

  // --- Household + current plan ------------------------------------------
  Future<Household> loadHousehold() async {
    final raw = (await _p).getString(_kHousehold);
    if (raw == null) return const Household();
    return Household.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveHousehold(Household h) async {
    await (await _p).setString(_kHousehold, jsonEncode(h.toJson()));
  }

  Future<String?> loadCurrentPlanId() async => (await _p).getString(_kCurrent);

  Future<void> saveCurrentPlanId(String id) async {
    await (await _p).setString(_kCurrent, id);
  }
}
