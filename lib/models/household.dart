/// User settings for the whole household. Stored as a single record.
class Household {
  /// How many people each cooked meal should feed.
  final int persons;

  /// Ingredient names, produce keys or tags the plan should avoid, lower-cased.
  final List<String> dislikes;

  final bool vegetarianOnly;
  final bool veganOnly;

  /// Distinct vegetables/legumes to aim for each week.
  final int weeklyVarietyTarget;

  const Household({
    this.persons = 2,
    this.dislikes = const [],
    this.vegetarianOnly = false,
    this.veganOnly = false,
    this.weeklyVarietyTarget = 20,
  });

  Household copyWith({
    int? persons,
    List<String>? dislikes,
    bool? vegetarianOnly,
    bool? veganOnly,
    int? weeklyVarietyTarget,
  }) =>
      Household(
        persons: persons ?? this.persons,
        dislikes: dislikes ?? this.dislikes,
        vegetarianOnly: vegetarianOnly ?? this.vegetarianOnly,
        veganOnly: veganOnly ?? this.veganOnly,
        weeklyVarietyTarget: weeklyVarietyTarget ?? this.weeklyVarietyTarget,
      );

  Map<String, dynamic> toJson() => {
        'persons': persons,
        'dislikes': dislikes,
        'vegetarianOnly': vegetarianOnly,
        'veganOnly': veganOnly,
        'weeklyVarietyTarget': weeklyVarietyTarget,
      };

  factory Household.fromJson(Map<String, dynamic> j) => Household(
        persons: (j['persons'] as num?)?.toInt() ?? 2,
        dislikes: ((j['dislikes'] as List?) ?? const []).cast<String>(),
        vegetarianOnly: (j['vegetarianOnly'] as bool?) ?? false,
        veganOnly: (j['veganOnly'] as bool?) ?? false,
        weeklyVarietyTarget: (j['weeklyVarietyTarget'] as num?)?.toInt() ?? 20,
      );
}
