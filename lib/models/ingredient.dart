/// Shopping-list grouping. Order here is the order items appear in the list.
enum IngredientCategory {
  produce('Obst & Gemüse'),
  legumes('Hülsenfrüchte'),
  dairy('Molkerei & Eier'),
  meatFish('Fleisch & Fisch'),
  pantry('Vorrat & Trockenwaren'),
  spices('Gewürze & Öle'),
  frozen('Tiefkühl'),
  other('Sonstiges');

  final String label;
  const IngredientCategory(this.label);

  static IngredientCategory fromName(String? name) =>
      IngredientCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => IngredientCategory.other,
      );
}

/// One ingredient line inside a recipe. Amounts are written for the recipe's
/// [Recipe.baseServings] and scaled from there.
class RecipeIngredient {
  final String name;
  final double amount;
  final String unit; // 'g', 'ml', 'Stück', 'EL', 'TL', 'Prise', 'Dose', 'Bund', 'Packung', ''
  final IngredientCategory category;

  /// When set, this ingredient counts toward the weekly vegetable/legume
  /// variety goal. The key is the canonical produce name used for counting
  /// distinct kinds (e.g. 'Karotte', 'Kichererbse').
  final String? produceKey;

  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.category = IngredientCategory.other,
    this.produceKey,
  });

  bool get countsAsVariety => produceKey != null;

  RecipeIngredient scale(double f) => RecipeIngredient(
        name: name,
        amount: amount * f,
        unit: unit,
        category: category,
        produceKey: produceKey,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'category': category.name,
        if (produceKey != null) 'produceKey': produceKey,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        name: j['name'] as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        unit: (j['unit'] as String?) ?? '',
        category: IngredientCategory.fromName(j['category'] as String?),
        produceKey: j['produceKey'] as String?,
      );
}
