import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/household.dart';
import '../models/recipe.dart';
import '../models/week_plan.dart';
import 'seed_recipes.dart';

/// Local SQLite persistence. Entities are stored as JSON in a `data` column —
/// simple, robust, and enough for a single-user offline app.
class Repository {
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'essensplan.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE recipes (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute('CREATE TABLE plans ('
            'id TEXT PRIMARY KEY, data TEXT NOT NULL, '
            'archived INTEGER NOT NULL DEFAULT 0, '
            'start_date TEXT, created_at TEXT)');
        await db.execute(
            'CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)');
        // Seed the built-in recipe library on first launch.
        final batch = db.batch();
        for (final r in seedRecipes) {
          batch.insert('recipes', {'id': r.id, 'data': jsonEncode(r.toJson())});
        }
        await batch.commit(noResult: true);
      },
    );
  }

  // --- Recipes -----------------------------------------------------------
  Future<List<Recipe>> loadRecipes() async {
    final db = await _database;
    final rows = await db.query('recipes');
    return rows
        .map((r) =>
            Recipe.fromJson(jsonDecode(r['data'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRecipe(Recipe recipe) async {
    final db = await _database;
    await db.insert(
      'recipes',
      {'id': recipe.id, 'data': jsonEncode(recipe.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRecipe(String id) async {
    final db = await _database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  /// Re-inserts any missing built-in recipes (used by "Rezepte zurücksetzen").
  Future<void> restoreSeedRecipes() async {
    final db = await _database;
    final batch = db.batch();
    for (final r in seedRecipes) {
      batch.insert(
        'recipes',
        {'id': r.id, 'data': jsonEncode(r.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // --- Plans -------------------------------------------------------------
  Future<List<WeekPlan>> loadPlans() async {
    final db = await _database;
    final rows = await db.query('plans', orderBy: 'start_date DESC');
    return rows
        .map((r) =>
            WeekPlan.fromJson(jsonDecode(r['data'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePlan(WeekPlan plan) async {
    final db = await _database;
    await db.insert(
      'plans',
      {
        'id': plan.id,
        'data': jsonEncode(plan.toJson()),
        'archived': plan.archived ? 1 : 0,
        'start_date': plan.startDate.toIso8601String(),
        'created_at': plan.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePlan(String id) async {
    final db = await _database;
    await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  // --- Key/value (household + current plan) ------------------------------
  Future<String?> _get(String key) async {
    final db = await _database;
    final rows = await db.query('kv', where: 'k = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['v'] as String;
  }

  Future<void> _set(String key, String value) async {
    final db = await _database;
    await db.insert('kv', {'k': key, 'v': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Household> loadHousehold() async {
    final raw = await _get('household');
    if (raw == null) return const Household();
    return Household.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveHousehold(Household h) =>
      _set('household', jsonEncode(h.toJson()));

  Future<String?> loadCurrentPlanId() => _get('currentPlanId');

  Future<void> saveCurrentPlanId(String id) => _set('currentPlanId', id);
}
