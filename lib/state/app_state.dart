import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../logic/nutrition_calc.dart';
import '../logic/plan_generator.dart';
import '../logic/shopping_list.dart';
import '../models/household.dart';
import '../models/recipe.dart';
import '../models/week_plan.dart';

/// Single source of truth for the UI. Wraps [Repository] and keeps everything
/// in memory so screens can read synchronously and rebuild on change.
class AppState extends ChangeNotifier {
  AppState(this._repo);

  final Repository _repo;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<Recipe> _recipes = [];
  List<WeekPlan> _plans = [];
  Household _household = const Household();
  String? _currentPlanId;

  Household get household => _household;
  List<Recipe> get recipes => List.unmodifiable(_recipes);
  List<WeekPlan> get plans => List.unmodifiable(_plans);

  Map<String, Recipe> get recipesById => {for (final r in _recipes) r.id: r};

  Recipe? recipeById(String? id) =>
      id == null ? null : recipesById[id];

  WeekPlan? get currentPlan {
    if (_currentPlanId == null) return null;
    for (final p in _plans) {
      if (p.id == _currentPlanId) return p;
    }
    return null;
  }

  /// All saved weeks except the active one — the archive for recycling.
  List<WeekPlan> get archivedPlans =>
      _plans.where((p) => p.id != _currentPlanId).toList();

  Future<void> load() async {
    _recipes = await _repo.loadRecipes();
    _plans = await _repo.loadPlans();
    _household = await _repo.loadHousehold();
    _currentPlanId = await _repo.loadCurrentPlanId();
    _loaded = true;
    notifyListeners();
  }

  // --- Analysis helpers --------------------------------------------------
  PlanAnalysis? get currentAnalysis {
    final plan = currentPlan;
    if (plan == null) return null;
    return analysePlan(
      plan,
      recipesById,
      persons: _household.persons,
      varietyTarget: _household.weeklyVarietyTarget,
    );
  }

  List<ShoppingSection> get currentShopping {
    final plan = currentPlan;
    if (plan == null) return const [];
    return buildShoppingList(plan, recipesById);
  }

  // --- Household ---------------------------------------------------------
  Future<void> saveHousehold(Household h) async {
    _household = h;
    await _repo.saveHousehold(h);
    notifyListeners();
  }

  // --- Recipes -----------------------------------------------------------
  Future<void> saveRecipe(Recipe recipe) async {
    final idx = _recipes.indexWhere((r) => r.id == recipe.id);
    if (idx >= 0) {
      _recipes[idx] = recipe;
    } else {
      _recipes = [..._recipes, recipe];
    }
    await _repo.saveRecipe(recipe);
    notifyListeners();
  }

  Future<void> deleteRecipe(String id) async {
    _recipes = _recipes.where((r) => r.id != id).toList();
    await _repo.deleteRecipe(id);
    notifyListeners();
  }

  Future<void> restoreSeedRecipes() async {
    await _repo.restoreSeedRecipes();
    _recipes = await _repo.loadRecipes();
    notifyListeners();
  }

  // --- Plans -------------------------------------------------------------
  Future<void> _upsertPlan(WeekPlan plan, {bool makeCurrent = false}) async {
    final idx = _plans.indexWhere((p) => p.id == plan.id);
    if (idx >= 0) {
      _plans[idx] = plan;
    } else {
      _plans = [plan, ..._plans];
    }
    _plans.sort((a, b) => b.startDate.compareTo(a.startDate));
    await _repo.savePlan(plan);
    if (makeCurrent) {
      _currentPlanId = plan.id;
      await _repo.saveCurrentPlanId(plan.id);
    }
    notifyListeners();
  }

  Future<WeekPlan> generatePlan(GenerateConfig config) async {
    final plan = generateWeekPlan(config, _recipes, _household);
    await _upsertPlan(plan, makeCurrent: true);
    return plan;
  }

  Future<void> setCurrentPlan(String id) async {
    _currentPlanId = id;
    await _repo.saveCurrentPlanId(id);
    notifyListeners();
  }

  Future<void> savePlan(WeekPlan plan) => _upsertPlan(plan);

  Future<void> updateSlot(int dayIndex, MealType meal, MealSlot slot) async {
    final plan = currentPlan;
    if (plan == null) return;
    await _upsertPlan(plan.withSlot(dayIndex, meal, slot));
  }

  Future<void> toggleChecked(String itemKey) async {
    final plan = currentPlan;
    if (plan == null) return;
    final checked = {...plan.checked};
    if (!checked.add(itemKey)) checked.remove(itemKey);
    await _upsertPlan(plan.copyWith(checked: checked));
  }

  Future<void> deletePlan(String id) async {
    _plans = _plans.where((p) => p.id != id).toList();
    await _repo.deletePlan(id);
    if (_currentPlanId == id) {
      _currentPlanId = _plans.isNotEmpty ? _plans.first.id : null;
      if (_currentPlanId != null) {
        await _repo.saveCurrentPlanId(_currentPlanId!);
      }
    }
    notifyListeners();
  }

  /// Recycle a past week onto a new start date and make it the active week.
  Future<WeekPlan> recyclePlan(WeekPlan source, DateTime newStart) async {
    final label = 'Woche ${newStart.day}.${newStart.month}.';
    final copy = source.recycleTo(newStart, label: label);
    await _upsertPlan(copy, makeCurrent: true);
    return copy;
  }
}
