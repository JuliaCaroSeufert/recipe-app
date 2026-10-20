import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../data/seed_photos.dart';
import '../logic/ai_photo.dart';
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
    await _applyBakedSeedPhotos();
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
    var r = recipe;
    // Give any new, non-seed recipe (import or manual) a styled AI photo if it
    // has none, so imported recipes look like the built-in ones. It's a single
    // deterministic image per recipe (generated on first view, then cached) —
    // no rate-limit issue the way loading many at once would be.
    if (r.imageUrl.isEmpty && r.source != RecipeSource.seed) {
      r = r.copyWith(imageUrl: aiPhotoUrl(r));
    }
    final idx = _recipes.indexWhere((e) => e.id == r.id);
    if (idx >= 0) {
      _recipes[idx] = r;
    } else {
      _recipes = [..._recipes, r];
    }
    await _repo.saveRecipe(r);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final r = recipeById(id);
    if (r == null) return;
    await saveRecipe(r.copyWith(isFavorite: !r.isFavorite));
  }

  Future<void> deleteRecipe(String id) async {
    _recipes = _recipes.where((r) => r.id != id).toList();
    await _repo.deleteRecipe(id);
    notifyListeners();
  }

  Future<void> restoreSeedRecipes() async {
    await _repo.restoreSeedRecipes();
    _recipes = await _repo.loadRecipes();
    await _applyBakedSeedPhotos();
    notifyListeners();
  }

  /// Forces every seed recipe's photo to the baked-in value ([kSeedPhotos],
  /// a bundled asset path), overriding any outdated URL so existing installs
  /// pick up the current photos and stale ones are cleared. Imported recipes
  /// keep their own photo.
  Future<void> _applyBakedSeedPhotos() async {
    for (var i = 0; i < _recipes.length; i++) {
      final r = _recipes[i];
      if (r.source != RecipeSource.seed) continue;
      final want = kSeedPhotos[r.id] ?? '';
      if (r.imageUrl != want) {
        _recipes[i] = r.copyWith(imageUrl: want);
        await _repo.saveRecipe(_recipes[i]);
      }
    }
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

  /// When each recipe was last planned, from past weeks (for favourite
  /// cadence). [excludeStart] skips a week with that start date, so
  /// regenerating the current week doesn't count against itself.
  Map<String, DateTime> _planHistory({DateTime? excludeStart}) {
    final out = <String, DateTime>{};
    for (final p in _plans) {
      if (excludeStart != null &&
          p.startDate.year == excludeStart.year &&
          p.startDate.month == excludeStart.month &&
          p.startDate.day == excludeStart.day) {
        continue;
      }
      for (final day in p.days) {
        for (final slot in day.meals.values) {
          final id = slot.recipeId;
          if (id == null) continue;
          final prev = out[id];
          if (prev == null || p.startDate.isAfter(prev)) out[id] = p.startDate;
        }
      }
    }
    return out;
  }

  Future<WeekPlan> generatePlan(GenerateConfig config) async {
    final base = DateTime(
        config.startDate.year, config.startDate.month, config.startDate.day);
    final plan = generateWeekPlan(
      config,
      _recipes,
      _household,
      history: _planHistory(excludeStart: base),
    );
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
