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

  /// Optional Google Gemini API key for the AI recipe import (stored locally,
  /// on this device only). Empty = AI import off, local parsing is used.
  final String geminiApiKey;

  /// Optional free Pexels API key (legacy; kept only so older stored data
  /// round-trips). No longer used for photos.
  final String pexelsApiKey;

  /// Optional free Spoonacular API key for real recipe photos (stored locally,
  /// on this device only). Empty = photos off, colourful emoji tiles are shown.
  final String spoonacularApiKey;

  /// Whether the first-run intro has been completed.
  final bool onboarded;

  const Household({
    this.persons = 2,
    this.dislikes = const [],
    this.vegetarianOnly = false,
    this.veganOnly = false,
    this.weeklyVarietyTarget = 20,
    this.geminiApiKey = '',
    this.pexelsApiKey = '',
    this.spoonacularApiKey = '',
    this.onboarded = false,
  });

  bool get hasAiKey => geminiApiKey.trim().isNotEmpty;
  bool get hasSpoonacularKey => spoonacularApiKey.trim().isNotEmpty;

  Household copyWith({
    int? persons,
    List<String>? dislikes,
    bool? vegetarianOnly,
    bool? veganOnly,
    int? weeklyVarietyTarget,
    String? geminiApiKey,
    String? pexelsApiKey,
    String? spoonacularApiKey,
    bool? onboarded,
  }) =>
      Household(
        persons: persons ?? this.persons,
        dislikes: dislikes ?? this.dislikes,
        vegetarianOnly: vegetarianOnly ?? this.vegetarianOnly,
        veganOnly: veganOnly ?? this.veganOnly,
        weeklyVarietyTarget: weeklyVarietyTarget ?? this.weeklyVarietyTarget,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        pexelsApiKey: pexelsApiKey ?? this.pexelsApiKey,
        spoonacularApiKey: spoonacularApiKey ?? this.spoonacularApiKey,
        onboarded: onboarded ?? this.onboarded,
      );

  Map<String, dynamic> toJson() => {
        'persons': persons,
        'dislikes': dislikes,
        'vegetarianOnly': vegetarianOnly,
        'veganOnly': veganOnly,
        'weeklyVarietyTarget': weeklyVarietyTarget,
        'geminiApiKey': geminiApiKey,
        'pexelsApiKey': pexelsApiKey,
        'spoonacularApiKey': spoonacularApiKey,
        'onboarded': onboarded,
      };

  factory Household.fromJson(Map<String, dynamic> j) => Household(
        persons: (j['persons'] as num?)?.toInt() ?? 2,
        dislikes: ((j['dislikes'] as List?) ?? const []).cast<String>(),
        vegetarianOnly: (j['vegetarianOnly'] as bool?) ?? false,
        veganOnly: (j['veganOnly'] as bool?) ?? false,
        weeklyVarietyTarget: (j['weeklyVarietyTarget'] as num?)?.toInt() ?? 20,
        geminiApiKey: (j['geminiApiKey'] as String?) ?? '',
        pexelsApiKey: (j['pexelsApiKey'] as String?) ?? '',
        spoonacularApiKey: (j['spoonacularApiKey'] as String?) ?? '',
        onboarded: (j['onboarded'] as bool?) ?? false,
      );
}
