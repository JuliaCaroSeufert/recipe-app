import 'ingredient.dart';
import 'nutrition.dart';

enum MealType {
  lunch('Mittagessen', 'Mittag'),
  dinner('Abendessen', 'Abend');

  final String label;
  final String shortLabel;
  const MealType(this.label, this.shortLabel);
}

enum RecipeSource {
  seed,
  manual,
  instagram,
}

/// A recipe in the user's library. Amounts in [ingredients] and the
/// [nutritionPerServing] are written for [baseServings] portions and scaled
/// elsewhere.
class Recipe {
  final String id;
  final String title;
  final String description;
  final String emoji;

  /// Optional real photo URL (filled from an imported post or a photo source
  /// like Pexels). Empty = show the colourful emoji tile instead.
  final String imageUrl;
  final int prepMinutes;
  final int baseServings;
  final List<MealType> suitableFor;
  final List<String> tags;
  final bool isVegetarian;
  final bool isVegan;

  /// Keeps and reheats well, so the generator may cook it once for several
  /// meals ("batch cooking").
  final bool batchFriendly;

  /// Whether the user marked this recipe as a favourite.
  final bool isFavorite;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final Nutrition nutritionPerServing;
  final RecipeSource source;
  final String? sourceUrl;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '🍽️',
    this.imageUrl = '',
    this.prepMinutes = 30,
    this.baseServings = 2,
    this.suitableFor = const [MealType.lunch, MealType.dinner],
    this.tags = const [],
    this.isVegetarian = false,
    this.isVegan = false,
    this.batchFriendly = false,
    this.isFavorite = false,
    this.ingredients = const [],
    this.steps = const [],
    this.nutritionPerServing = Nutrition.zero,
    this.source = RecipeSource.seed,
    this.sourceUrl,
    required this.createdAt,
  });

  bool get isQuick => prepMinutes <= 30;

  /// Comma-separated English-ish keywords for a direct photo lookup, derived
  /// from the title (common German food words are mapped to English so photo
  /// search matches better).
  String get photoKeywords {
    const map = {
      'linsen': 'lentils', 'linsen-': 'lentils', 'kichererbsen': 'chickpea',
      'kichererbse': 'chickpea', 'bohnen': 'beans', 'bohne': 'beans',
      'kürbis': 'pumpkin', 'kürbissuppe': 'pumpkin,soup',
      'süßkartoffel': 'sweet,potato', 'hähnchen': 'chicken',
      'hähnchen-': 'chicken', 'pute': 'turkey', 'rind': 'beef',
      'rinder': 'beef', 'lachs': 'salmon', 'nudeln': 'pasta',
      'pasta': 'pasta', 'spaghetti': 'pasta', 'suppe': 'soup',
      'salat': 'salad', 'curry': 'curry', 'dal': 'dal,curry',
      'chili': 'chili', 'shakshuka': 'shakshuka', 'falafel': 'falafel',
      'gnocchi': 'gnocchi', 'couscous': 'couscous', 'omelett': 'omelette',
      'bowl': 'bowl', 'wok': 'stir,fry', 'minestrone': 'minestrone,soup',
      'spinat': 'spinach', 'tofu': 'tofu', 'feta': 'feta',
      'halloumi': 'halloumi', 'ofengemüse': 'roasted,vegetables',
      'rote': 'beetroot', 'bete': 'beetroot', 'mangold': 'chard',
      'pfanne': '', 'bolognese': 'bolognese', 'dal-': 'dal',
    };
    const stop = {
      'mit', 'und', 'der', 'die', 'das', 'vom', 'im', 'auf', 'in', 'aus',
      'cremige', 'cremiges', 'schnelle', 'schnelles', 'einfache', 'bunte',
      'würziges', 'würzige', 'gefüllte', 'a', 'la',
    };
    final words = <String>[];
    for (final raw in title.toLowerCase().split(RegExp(r'[\s\-&,]+'))) {
      final w = raw.replaceAll(RegExp(r'[^a-zäöüß]'), '');
      if (w.isEmpty || stop.contains(w)) continue;
      final mapped = map[w];
      if (mapped != null) {
        if (mapped.isNotEmpty) words.add(mapped);
      } else {
        words.add(w);
      }
      if (words.length >= 3) break;
    }
    if (words.isEmpty) words.add('food');
    return '${words.join(',')},food,meal';
  }

  /// Up to two short, appetising badges derived from the recipe (for cards).
  List<String> get highlights {
    final out = <String>[];
    if (nutritionPerServing.protein >= 25) out.add('High Protein');
    if (nutritionPerServing.fiber >= 10) out.add('Ballaststoffreich');
    if (isVegan) {
      out.add('Vegan');
    } else if (isVegetarian) {
      out.add('Veggie');
    }
    if (isQuick) out.add('Schnell');
    return out.take(2).toList();
  }

  /// Canonical produce/legume kinds this recipe contributes to the weekly
  /// variety goal.
  Set<String> get produceKeys =>
      ingredients.map((i) => i.produceKey).whereType<String>().toSet();

  /// Lower-cased ingredient names plus tags, for dislike matching.
  Set<String> get matchTerms => {
        ...ingredients.map((i) => i.name.toLowerCase()),
        ...ingredients
            .map((i) => i.produceKey?.toLowerCase())
            .whereType<String>(),
        ...tags.map((t) => t.toLowerCase()),
      };

  Recipe copyWith({
    String? title,
    String? description,
    String? emoji,
    String? imageUrl,
    int? prepMinutes,
    int? baseServings,
    List<MealType>? suitableFor,
    List<String>? tags,
    bool? isVegetarian,
    bool? isVegan,
    bool? batchFriendly,
    bool? isFavorite,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    Nutrition? nutritionPerServing,
    RecipeSource? source,
    String? sourceUrl,
  }) =>
      Recipe(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        emoji: emoji ?? this.emoji,
        imageUrl: imageUrl ?? this.imageUrl,
        prepMinutes: prepMinutes ?? this.prepMinutes,
        baseServings: baseServings ?? this.baseServings,
        suitableFor: suitableFor ?? this.suitableFor,
        tags: tags ?? this.tags,
        isVegetarian: isVegetarian ?? this.isVegetarian,
        isVegan: isVegan ?? this.isVegan,
        batchFriendly: batchFriendly ?? this.batchFriendly,
        isFavorite: isFavorite ?? this.isFavorite,
        ingredients: ingredients ?? this.ingredients,
        steps: steps ?? this.steps,
        nutritionPerServing: nutritionPerServing ?? this.nutritionPerServing,
        source: source ?? this.source,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'imageUrl': imageUrl,
        'prepMinutes': prepMinutes,
        'baseServings': baseServings,
        'suitableFor': suitableFor.map((m) => m.name).toList(),
        'tags': tags,
        'isVegetarian': isVegetarian,
        'isVegan': isVegan,
        'batchFriendly': batchFriendly,
        'isFavorite': isFavorite,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
        'nutritionPerServing': nutritionPerServing.toJson(),
        'source': source.name,
        'sourceUrl': sourceUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '🍽️',
        imageUrl: (j['imageUrl'] as String?) ?? '',
        prepMinutes: (j['prepMinutes'] as num?)?.toInt() ?? 30,
        baseServings: (j['baseServings'] as num?)?.toInt() ?? 2,
        suitableFor: ((j['suitableFor'] as List?) ?? const ['lunch', 'dinner'])
            .map((n) => MealType.values.firstWhere(
                  (m) => m.name == n,
                  orElse: () => MealType.dinner,
                ))
            .toList(),
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
        isVegetarian: (j['isVegetarian'] as bool?) ?? false,
        isVegan: (j['isVegan'] as bool?) ?? false,
        batchFriendly: (j['batchFriendly'] as bool?) ?? false,
        isFavorite: (j['isFavorite'] as bool?) ?? false,
        ingredients: ((j['ingredients'] as List?) ?? const [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: ((j['steps'] as List?) ?? const []).cast<String>(),
        nutritionPerServing: Nutrition.fromJson(
            (j['nutritionPerServing'] as Map?)?.cast<String, dynamic>() ??
                const {}),
        source: RecipeSource.values.firstWhere(
          (s) => s.name == j['source'],
          orElse: () => RecipeSource.manual,
        ),
        sourceUrl: j['sourceUrl'] as String?,
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
