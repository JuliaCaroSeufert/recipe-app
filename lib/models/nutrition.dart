/// Nutritional values. Macro values in grams, kcal in kilocalories, all
/// micronutrients in the unit noted next to each field. All values are
/// "per serving" on a [Recipe] and "absolute" once aggregated for a plan.
class Nutrition {
  final double kcal;
  final double protein; // g
  final double carbs; // g
  final double fat; // g
  final double fiber; // g
  // micronutrients
  final double iron; // mg
  final double calcium; // mg
  final double magnesium; // mg
  final double potassium; // mg
  final double zinc; // mg
  final double vitaminC; // mg
  final double vitaminA; // µg RAE
  final double folate; // µg

  const Nutrition({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.iron = 0,
    this.calcium = 0,
    this.magnesium = 0,
    this.potassium = 0,
    this.zinc = 0,
    this.vitaminC = 0,
    this.vitaminA = 0,
    this.folate = 0,
  });

  static const Nutrition zero = Nutrition();

  Nutrition operator +(Nutrition o) => Nutrition(
        kcal: kcal + o.kcal,
        protein: protein + o.protein,
        carbs: carbs + o.carbs,
        fat: fat + o.fat,
        fiber: fiber + o.fiber,
        iron: iron + o.iron,
        calcium: calcium + o.calcium,
        magnesium: magnesium + o.magnesium,
        potassium: potassium + o.potassium,
        zinc: zinc + o.zinc,
        vitaminC: vitaminC + o.vitaminC,
        vitaminA: vitaminA + o.vitaminA,
        folate: folate + o.folate,
      );

  Nutrition scale(double f) => Nutrition(
        kcal: kcal * f,
        protein: protein * f,
        carbs: carbs * f,
        fat: fat * f,
        fiber: fiber * f,
        iron: iron * f,
        calcium: calcium * f,
        magnesium: magnesium * f,
        potassium: potassium * f,
        zinc: zinc * f,
        vitaminC: vitaminC * f,
        vitaminA: vitaminA * f,
        folate: folate * f,
      );

  /// Reads a field by its machine key — used by the generator and the
  /// nutrition UI so they can iterate over nutrients generically.
  double byKey(String key) {
    switch (key) {
      case 'kcal':
        return kcal;
      case 'protein':
        return protein;
      case 'carbs':
        return carbs;
      case 'fat':
        return fat;
      case 'fiber':
        return fiber;
      case 'iron':
        return iron;
      case 'calcium':
        return calcium;
      case 'magnesium':
        return magnesium;
      case 'potassium':
        return potassium;
      case 'zinc':
        return zinc;
      case 'vitaminC':
        return vitaminC;
      case 'vitaminA':
        return vitaminA;
      case 'folate':
        return folate;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'iron': iron,
        'calcium': calcium,
        'magnesium': magnesium,
        'potassium': potassium,
        'zinc': zinc,
        'vitaminC': vitaminC,
        'vitaminA': vitaminA,
        'folate': folate,
      };

  factory Nutrition.fromJson(Map<String, dynamic> j) {
    double g(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return Nutrition(
      kcal: g('kcal'),
      protein: g('protein'),
      carbs: g('carbs'),
      fat: g('fat'),
      fiber: g('fiber'),
      iron: g('iron'),
      calcium: g('calcium'),
      magnesium: g('magnesium'),
      potassium: g('potassium'),
      zinc: g('zinc'),
      vitaminC: g('vitaminC'),
      vitaminA: g('vitaminA'),
      folate: g('folate'),
    );
  }
}

/// Static description of one nutrient for the UI and for target comparisons.
class NutrientInfo {
  final String key;
  final String label;
  final String unit;

  /// Reference intake for one adult per day (DACH reference values, rounded).
  final double dailyPerPerson;
  final bool isMacro;

  const NutrientInfo(
    this.key,
    this.label,
    this.unit,
    this.dailyPerPerson, {
    this.isMacro = false,
  });
}

/// Order matters: this drives the nutrition table layout.
const List<NutrientInfo> kNutrients = [
  NutrientInfo('kcal', 'Kalorien', 'kcal', 2000, isMacro: true),
  NutrientInfo('protein', 'Eiweiß', 'g', 60, isMacro: true),
  NutrientInfo('carbs', 'Kohlenhydrate', 'g', 250, isMacro: true),
  NutrientInfo('fat', 'Fett', 'g', 70, isMacro: true),
  NutrientInfo('fiber', 'Ballaststoffe', 'g', 30, isMacro: true),
  NutrientInfo('iron', 'Eisen', 'mg', 12),
  NutrientInfo('calcium', 'Kalzium', 'mg', 1000),
  NutrientInfo('magnesium', 'Magnesium', 'mg', 350),
  NutrientInfo('potassium', 'Kalium', 'mg', 3500),
  NutrientInfo('zinc', 'Zink', 'mg', 10),
  NutrientInfo('vitaminC', 'Vitamin C', 'mg', 100),
  NutrientInfo('vitaminA', 'Vitamin A', 'µg', 850),
  NutrientInfo('folate', 'Folat', 'µg', 300),
];
