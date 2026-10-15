import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/week_plan.dart';

/// One aggregated line on the shopping list.
class ShoppingItem {
  final String name;
  final double amount;
  final String unit;
  final IngredientCategory category;

  const ShoppingItem({
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
  });

  /// Stable key for the checked-off set (name + unit).
  String get key => '${name.toLowerCase()}|$unit';

  String get amountLabel {
    if (amount <= 0) return '';
    final rounded = amount >= 10 ? amount.round() : amount;
    final text = rounded is int
        ? rounded.toString()
        : (amount == amount.roundToDouble()
            ? amount.round().toString()
            : amount.toStringAsFixed(1));
    return unit.isEmpty ? text : '$text $unit';
  }
}

/// A category with its items, for the grouped list UI.
class ShoppingSection {
  final IngredientCategory category;
  final List<ShoppingItem> items;
  const ShoppingSection(this.category, this.items);
}

/// Builds the shopping list from the cooked slots of [plan]. Leftover and
/// order slots add nothing. Amounts are scaled from each recipe's base
/// servings to the servings cooked in the slot, then merged by (name, unit).
List<ShoppingSection> buildShoppingList(
  WeekPlan plan,
  Map<String, Recipe> recipesById,
) {
  final merged = <String, ShoppingItem>{};

  for (final slot in plan.cookSlots) {
    final recipe = recipesById[slot.recipeId];
    if (recipe == null) continue;
    final factor =
        recipe.baseServings == 0 ? 1.0 : slot.servings / recipe.baseServings;
    for (final ing in recipe.ingredients) {
      final scaled = ing.scale(factor);
      final key = '${scaled.name.toLowerCase()}|${scaled.unit}';
      final existing = merged[key];
      if (existing == null) {
        merged[key] = ShoppingItem(
          name: scaled.name,
          amount: scaled.amount,
          unit: scaled.unit,
          category: scaled.category,
        );
      } else {
        merged[key] = ShoppingItem(
          name: existing.name,
          amount: existing.amount + scaled.amount,
          unit: existing.unit,
          category: existing.category,
        );
      }
    }
  }

  final byCategory = <IngredientCategory, List<ShoppingItem>>{};
  for (final item in merged.values) {
    byCategory.putIfAbsent(item.category, () => []).add(item);
  }

  final sections = <ShoppingSection>[];
  for (final cat in IngredientCategory.values) {
    final items = byCategory[cat];
    if (items == null || items.isEmpty) continue;
    items.sort((a, b) => a.name.compareTo(b.name));
    sections.add(ShoppingSection(cat, items));
  }
  return sections;
}

/// Renders the shopping list as plain text for sharing / export.
String shoppingListToText(List<ShoppingSection> sections, {String? title}) {
  final buf = StringBuffer();
  if (title != null) {
    buf.writeln('🛒 $title');
    buf.writeln();
  }
  for (final section in sections) {
    buf.writeln('${section.category.label}:');
    for (final item in section.items) {
      final amount = item.amountLabel;
      buf.writeln('  • ${item.name}${amount.isEmpty ? '' : ' – $amount'}');
    }
    buf.writeln();
  }
  return buf.toString().trimRight();
}
