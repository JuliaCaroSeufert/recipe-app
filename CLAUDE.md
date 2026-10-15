# Essensplan — build notes

Offline-first **Flutter (Dart)** meal-planning app for phone. Weekly plan for
lunch + dinner with recipe suggestions, nutrition optimisation (macros +
micros), vegetable-variety goal (≥20/week), batch cooking, order/eat-out days,
shopping list, Instagram import and week recycling. All data is local (SQLite
via `sqflite`); no backend.

Full feature overview and run instructions live in `README.md`.

## Conventions

- User-facing strings are **German**. Code, comments, commits stay English.
- Keep business logic **pure and testable** in `lib/logic/` — it must not depend
  on Flutter or the database. Screens read everything through `AppState`
  (`lib/state/app_state.dart`); only the `Repository` touches `sqflite`.
- Domain models in `lib/models/` own their own `toJson`/`fromJson`; the
  repository stores them as JSON text columns.
- `flutter analyze` must report **no issues** and `flutter test` must pass
  before a commit.
- Nutrition keys are centralised in `lib/models/nutrition.dart` (`kNutrients`);
  add a nutrient there and `Nutrition.byKey` so UI and generator pick it up.
- When you add a seed recipe, tag each vegetable/legume ingredient with a
  `produceKey` so it counts toward the weekly variety goal.

## Environment

This repo was bootstrapped with Flutter `stable` (Dart 3.13+). In this cloud
container the Android SDK is not installed, so `flutter build apk`/`bundle`
can't run here — use `flutter analyze`, `flutter test` and `flutter build web`
(or `-d chrome`) to verify compilation.
