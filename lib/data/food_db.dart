import '../models/ingredient.dart';
import '../models/nutrition.dart';

/// Diet relevance of a food, used to infer vegetarian/vegan on import.
enum FoodKind { plant, dairyEgg, meatFish }

/// One known ingredient: how to categorise it, whether it counts as a
/// vegetable/legume, its nutrition per 100 g and typical weights for piece/
/// can/bunch units. Values are rounded reference estimates (USDA/BLS-based).
class FoodEntry {
  final List<String> keys; // lower-case match stems
  final IngredientCategory category;
  final String? produceKey; // canonical name if it counts toward variety
  final FoodKind kind;
  final Nutrition per100g;
  final double gramsPerPiece;
  final double gramsPerCan;
  final double gramsPerBunch;

  const FoodEntry(
    this.keys,
    this.category,
    this.per100g, {
    this.produceKey,
    this.kind = FoodKind.plant,
    this.gramsPerPiece = 0,
    this.gramsPerCan = 240,
    this.gramsPerBunch = 50,
  });
}

const _p = IngredientCategory.produce;
const _l = IngredientCategory.legumes;
const _d = IngredientCategory.dairy;
const _m = IngredientCategory.meatFish;
const _pa = IngredientCategory.pantry;
const _s = IngredientCategory.spices;

// Compact nutrition helper (per 100 g).
Nutrition _n(double kcal, double protein, double carbs, double fat, double fiber,
        {double iron = 0,
        double calcium = 0,
        double magnesium = 0,
        double potassium = 0,
        double zinc = 0,
        double vitaminC = 0,
        double vitaminA = 0,
        double folate = 0}) =>
    Nutrition(
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      iron: iron,
      calcium: calcium,
      magnesium: magnesium,
      potassium: potassium,
      zinc: zinc,
      vitaminC: vitaminC,
      vitaminA: vitaminA,
      folate: folate,
    );

/// The built-in food knowledge base. Longest matching key wins at lookup.
final List<FoodEntry> foodDb = [
  // --- Vegetables -------------------------------------------------------
  FoodEntry(['zwiebel', 'rote zwiebel'], _p, _n(40, 1.1, 9, 0.1, 1.7, vitaminC: 7),
      produceKey: 'Zwiebel', gramsPerPiece: 110),
  FoodEntry(['frühlingszwiebel', 'lauchzwiebel'], _p,
      _n(32, 1.8, 7, 0.2, 2.6, vitaminC: 18),
      produceKey: 'Frühlingszwiebel', gramsPerPiece: 15),
  FoodEntry(['knoblauch'], _p, _n(149, 6.4, 33, 0.5, 2.1),
      produceKey: 'Knoblauch', gramsPerPiece: 5),
  FoodEntry(['karotte', 'möhre', 'karotten', 'möhren'], _p,
      _n(41, 0.9, 10, 0.2, 2.8, potassium: 320, vitaminA: 835),
      produceKey: 'Karotte', gramsPerPiece: 60),
  FoodEntry(['paprika'], _p, _n(31, 1, 6, 0.3, 2.1, vitaminC: 128, vitaminA: 157),
      produceKey: 'Paprika', gramsPerPiece: 150),
  FoodEntry(['cherrytomaten', 'tomate', 'tomaten'], _p,
      _n(18, 0.9, 3.9, 0.2, 1.2, potassium: 237, vitaminC: 14, vitaminA: 42),
      produceKey: 'Tomate', gramsPerPiece: 80),
  FoodEntry(['zucchini'], _p, _n(17, 1.2, 3.1, 0.3, 1, vitaminC: 18),
      produceKey: 'Zucchini', gramsPerPiece: 200),
  FoodEntry(['aubergine'], _p, _n(25, 1, 6, 0.2, 3),
      produceKey: 'Aubergine', gramsPerPiece: 250),
  FoodEntry(['brokkoli', 'broccoli'], _p,
      _n(34, 2.8, 7, 0.4, 2.6, calcium: 47, vitaminC: 89, folate: 63),
      produceKey: 'Brokkoli'),
  FoodEntry(['blumenkohl'], _p, _n(25, 1.9, 5, 0.3, 2, vitaminC: 48, folate: 57),
      produceKey: 'Blumenkohl'),
  FoodEntry(['babyspinat', 'spinat'], _p,
      _n(23, 2.9, 3.6, 0.4, 2.2,
          iron: 2.7, calcium: 99, magnesium: 79, vitaminC: 28, vitaminA: 469, folate: 194),
      produceKey: 'Spinat'),
  FoodEntry(['mangold'], _p, _n(19, 1.8, 3.7, 0.2, 1.6, iron: 1.8, vitaminA: 306),
      produceKey: 'Mangold'),
  FoodEntry(['pak choi', 'pakchoi'], _p,
      _n(13, 1.5, 2.2, 0.2, 1, calcium: 105, vitaminC: 45, vitaminA: 223),
      produceKey: 'Pak Choi'),
  FoodEntry(['lauch', 'porree'], _p, _n(61, 1.5, 14, 0.3, 1.8, vitaminC: 12),
      produceKey: 'Lauch', gramsPerPiece: 150),
  FoodEntry(['staudensellerie', 'sellerie'], _p, _n(16, 0.7, 3, 0.2, 1.6),
      produceKey: 'Sellerie', gramsPerPiece: 40),
  FoodEntry(['fenchel'], _p, _n(31, 1.2, 7, 0.2, 3.1, vitaminC: 12),
      produceKey: 'Fenchel', gramsPerPiece: 200),
  FoodEntry(['kürbis', 'hokkaido'], _p, _n(26, 1, 6.5, 0.1, 0.5, vitaminA: 426),
      produceKey: 'Kürbis'),
  FoodEntry(['süßkartoffel'], _p, _n(86, 1.6, 20, 0.1, 3, vitaminA: 709),
      produceKey: 'Süßkartoffel', gramsPerPiece: 200),
  FoodEntry(['kartoffel', 'kartoffeln'], _p, _n(77, 2, 17, 0.1, 2.2, vitaminC: 19),
      gramsPerPiece: 120),
  FoodEntry(['champignon', 'champignons', 'pilze'], _p,
      _n(22, 3.1, 3.3, 0.3, 1),
      produceKey: 'Champignon'),
  FoodEntry(['rosenkohl'], _p, _n(43, 3.4, 9, 0.3, 3.8, vitaminC: 85, folate: 61),
      produceKey: 'Rosenkohl'),
  FoodEntry(['rote bete', 'rote beete'], _p,
      _n(43, 1.6, 10, 0.2, 2.8, folate: 109),
      produceKey: 'Rote Bete'),
  FoodEntry(['gurke'], _p, _n(15, 0.7, 3.6, 0.1, 0.5),
      produceKey: 'Gurke', gramsPerPiece: 300),
  FoodEntry(['avocado'], _p, _n(160, 2, 9, 15, 7, potassium: 485, folate: 81),
      produceKey: 'Avocado', gramsPerPiece: 150),
  FoodEntry(['rucola'], _p, _n(25, 2.6, 3.7, 0.7, 1.6, calcium: 160, vitaminA: 119),
      produceKey: 'Rucola'),
  FoodEntry(['rotkohl', 'rotkraut'], _p, _n(31, 1.4, 7, 0.2, 2.1, vitaminC: 57),
      produceKey: 'Rotkohl'),
  FoodEntry(['mais'], _pa, _n(86, 3.2, 19, 1.2, 2.7),
      produceKey: 'Mais'),
  FoodEntry(['erbsen'], _p, _n(81, 5, 14, 0.4, 5, vitaminC: 40, folate: 65),
      produceKey: 'Erbse'),
  FoodEntry(['grüne bohnen', 'prinzessbohnen'], _p, _n(31, 1.8, 7, 0.2, 2.7),
      produceKey: 'Grüne Bohne'),
  FoodEntry(['edamame'], _l, _n(121, 11, 9, 5, 5, iron: 2.3, folate: 311),
      produceKey: 'Edamame'),
  FoodEntry(['ingwer'], _p, _n(80, 1.8, 18, 0.8, 2), produceKey: 'Ingwer'),
  // --- Legumes (dry vs. canned handled by typical weights) --------------
  FoodEntry(['kichererbsen', 'kichererbse'], _l,
      _n(164, 8.9, 27, 2.6, 7.6, iron: 2.9, magnesium: 48, folate: 172),
      produceKey: 'Kichererbse', gramsPerCan: 240),
  FoodEntry(['rote linsen'], _l,
      _n(116, 9, 20, 0.4, 8, iron: 3.3, folate: 181),
      produceKey: 'Rote Linsen'),
  FoodEntry(['belugalinsen', 'beluga'], _l,
      _n(116, 9, 20, 0.4, 8, iron: 3.3, folate: 181),
      produceKey: 'Belugalinsen'),
  FoodEntry(['braune linsen', 'linsen'], _l,
      _n(116, 9, 20, 0.4, 8, iron: 3.3, folate: 181),
      produceKey: 'Braune Linsen'),
  FoodEntry(['kidneybohnen', 'kidney'], _l,
      _n(127, 8.7, 23, 0.5, 6.4, iron: 2.9, folate: 130),
      produceKey: 'Kidneybohne', gramsPerCan: 240),
  FoodEntry(['schwarze bohnen'], _l,
      _n(132, 8.9, 24, 0.5, 8.7, iron: 2.1, folate: 149),
      produceKey: 'Schwarze Bohne', gramsPerCan: 240),
  FoodEntry(['weiße bohnen', 'cannellini'], _l,
      _n(139, 9.7, 25, 0.5, 6.3, iron: 3.7, folate: 90),
      produceKey: 'Weiße Bohne', gramsPerCan: 240),
  // --- Dairy & eggs -----------------------------------------------------
  FoodEntry(['ei', 'eier'], _d, _n(143, 13, 0.7, 10, 0, iron: 1.8, calcium: 56),
      kind: FoodKind.dairyEgg, gramsPerPiece: 55),
  FoodEntry(['feta'], _d, _n(264, 14, 4, 21, 0, calcium: 493),
      kind: FoodKind.dairyEgg),
  FoodEntry(['mozzarella'], _d, _n(280, 22, 2, 21, 0, calcium: 505),
      kind: FoodKind.dairyEgg),
  FoodEntry(['parmesan'], _d, _n(392, 36, 3, 25, 0, calcium: 1184),
      kind: FoodKind.dairyEgg),
  FoodEntry(['ricotta'], _d, _n(174, 11, 3, 13, 0, calcium: 207),
      kind: FoodKind.dairyEgg),
  FoodEntry(['halloumi'], _d, _n(321, 22, 2, 25, 0, calcium: 700),
      kind: FoodKind.dairyEgg),
  FoodEntry(['ziegenkäse'], _d, _n(364, 22, 0.1, 30, 0, calcium: 298),
      kind: FoodKind.dairyEgg),
  FoodEntry(['gouda', 'käse', 'reibekäse'], _d,
      _n(356, 25, 2.2, 27, 0, calcium: 700),
      kind: FoodKind.dairyEgg),
  FoodEntry(['joghurt', 'jogurt'], _d, _n(61, 3.5, 4.7, 3.3, 0, calcium: 121),
      kind: FoodKind.dairyEgg),
  FoodEntry(['quark'], _d, _n(67, 12, 3.3, 0.2, 0, calcium: 90),
      kind: FoodKind.dairyEgg),
  FoodEntry(['schmand', 'crème fraîche', 'creme fraiche'], _d,
      _n(240, 2.8, 3.5, 24, 0),
      kind: FoodKind.dairyEgg),
  FoodEntry(['sahne', 'rahm'], _d, _n(290, 2.3, 3, 30, 0),
      kind: FoodKind.dairyEgg),
  FoodEntry(['milch'], _d, _n(64, 3.4, 4.8, 3.5, 0, calcium: 120),
      kind: FoodKind.dairyEgg),
  FoodEntry(['butter'], _d, _n(717, 0.9, 0.1, 81, 0), kind: FoodKind.dairyEgg),
  FoodEntry(['tofu'], _d, _n(76, 8, 1.9, 4.8, 0.3, iron: 2.7, calcium: 350)),
  // --- Meat & fish ------------------------------------------------------
  FoodEntry(['hähnchenbrust', 'hühnerbrust', 'hähnchen', 'hühnchen'], _m,
      _n(165, 31, 0, 3.6, 0, zinc: 1),
      kind: FoodKind.meatFish, gramsPerPiece: 150),
  FoodEntry(['putenbrust', 'pute', 'truthahn'], _m, _n(157, 29, 0, 4, 0),
      kind: FoodKind.meatFish),
  FoodEntry(['hackfleisch', 'gehacktes', 'rinderhack'], _m,
      _n(250, 26, 0, 17, 0, iron: 2.7, zinc: 4.8),
      kind: FoodKind.meatFish),
  FoodEntry(['rinderstreifen', 'rind', 'steak'], _m,
      _n(250, 26, 0, 15, 0, iron: 2.6, zinc: 4.8),
      kind: FoodKind.meatFish),
  FoodEntry(['schwein', 'schweine', 'kasseler'], _m, _n(242, 27, 0, 14, 0),
      kind: FoodKind.meatFish),
  FoodEntry(['speck', 'bacon', 'schinken'], _m, _n(300, 20, 1, 24, 0),
      kind: FoodKind.meatFish),
  FoodEntry(['lachs', 'lachsfilet'], _m, _n(208, 20, 0, 13, 0, potassium: 363),
      kind: FoodKind.meatFish, gramsPerPiece: 150),
  FoodEntry(['thunfisch'], _m, _n(132, 28, 0, 1, 0), kind: FoodKind.meatFish),
  FoodEntry(['garnelen', 'shrimps'], _m, _n(99, 24, 0.2, 0.3, 0),
      kind: FoodKind.meatFish),
  // --- Pantry / grains --------------------------------------------------
  FoodEntry(['spaghetti', 'penne', 'nudeln', 'pasta', 'vollkornpasta', 'mie-nudeln', 'mie'], _pa,
      _n(371, 13, 75, 1.5, 3, magnesium: 53)),
  FoodEntry(['reis'], _pa, _n(360, 7, 79, 0.6, 1.3)),
  FoodEntry(['couscous'], _pa, _n(376, 13, 77, 0.6, 5)),
  FoodEntry(['bulgur'], _pa, _n(342, 12, 76, 1.3, 18, magnesium: 164)),
  FoodEntry(['quinoa'], _pa, _n(368, 14, 64, 6, 7, iron: 4.6, magnesium: 197)),
  FoodEntry(['haferflocken', 'hafer'], _pa,
      _n(372, 13, 60, 7, 10, iron: 4.7, magnesium: 138)),
  FoodEntry(['mehl'], _pa, _n(364, 10, 76, 1, 2.7)),
  FoodEntry(['gnocchi'], _pa, _n(157, 3.6, 33, 1, 2)),
  FoodEntry(['fladenbrot', 'brot', 'baguette', 'toast'], _pa,
      _n(265, 9, 49, 3.2, 4)),
  FoodEntry(['kokosmilch'], _pa, _n(230, 2.3, 6, 24, 2.2)),
  FoodEntry(['passierte tomaten', 'gehackte tomaten', 'dosentomaten', 'tomatensauce'], _pa,
      _n(32, 1.6, 7, 0.3, 1.5, vitaminC: 15),
      produceKey: 'Tomate', gramsPerCan: 400),
  FoodEntry(['tomatenmark'], _pa, _n(82, 4.3, 19, 0.5, 4)),
  FoodEntry(['gemüsebrühe', 'brühe', 'fond'], _pa, _n(4, 0.3, 0.5, 0, 0)),
  FoodEntry(['hummus'], _pa, _n(177, 8, 20, 9, 6, iron: 2.4),
      produceKey: 'Kichererbse'),
  FoodEntry(['falafel'], _pa, _n(333, 13, 32, 18, 5),
      produceKey: 'Kichererbse', gramsPerPiece: 25),
  FoodEntry(['walnüsse', 'walnuss'], _pa, _n(654, 15, 14, 65, 7, magnesium: 158)),
  FoodEntry(['erdnüsse', 'erdnuss'], _pa, _n(567, 26, 16, 49, 9)),
  FoodEntry(['pinienkerne'], _pa, _n(673, 14, 13, 68, 4)),
  FoodEntry(['mandeln'], _pa, _n(579, 21, 22, 50, 12, calcium: 269, magnesium: 270)),
  FoodEntry(['sesam'], _pa, _n(573, 18, 23, 50, 12, calcium: 975)),
  FoodEntry(['zucker', 'honig'], _pa, _n(340, 0, 85, 0, 0)),
  // --- Spices & oils (negligible nutrition) -----------------------------
  FoodEntry(['olivenöl', 'öl', 'rapsöl', 'sesamöl'], _s, _n(884, 0, 0, 100, 0)),
  FoodEntry(['sojasauce', 'sojasoße'], _s, _n(53, 8, 5, 0.6, 0.8)),
  FoodEntry(['balsamico', 'essig'], _s, _n(88, 0.5, 17, 0, 0)),
  FoodEntry(['senf'], _s, _n(66, 4, 6, 3.3, 3)),
  FoodEntry(['currypaste', 'currypulver', 'curry'], _s, _n(80, 3, 10, 3, 5)),
  FoodEntry(['petersilie', 'minze', 'basilikum', 'koriander', 'kräuter'], _s,
      _n(36, 3, 6, 0.8, 3.3, vitaminC: 130, vitaminA: 421), gramsPerBunch: 30),
];

String _normalize(String name) {
  var s = name.toLowerCase().trim();
  final comma = s.indexOf(',');
  if (comma > 0) s = s.substring(0, comma);
  final paren = s.indexOf('(');
  if (paren > 0) s = s.substring(0, paren);
  return s.trim();
}

/// Finds the best-matching [FoodEntry] for an ingredient name (longest key
/// that appears in the name), or null when unknown.
FoodEntry? lookupFood(String name) {
  final s = _normalize(name);
  if (s.isEmpty) return null;
  FoodEntry? best;
  var bestLen = 0;
  for (final entry in foodDb) {
    for (final key in entry.keys) {
      if (s.contains(key) && key.length > bestLen) {
        best = entry;
        bestLen = key.length;
      }
    }
  }
  return best;
}

/// Converts an ingredient amount + unit to grams using the food's typical
/// weights. Returns 0 when it can't be estimated.
double gramsOf(double amount, String unit, FoodEntry entry) {
  switch (unit) {
    case 'g':
      return amount;
    case 'kg':
      return amount * 1000;
    case 'ml':
      return amount;
    case 'l':
      return amount * 1000;
    case 'EL':
      return amount * 15;
    case 'TL':
      return amount * 5;
    case 'Prise':
      return 1;
    case 'Tasse':
      return amount * 150;
    case 'Dose':
      return amount * entry.gramsPerCan;
    case 'Bund':
      return amount * entry.gramsPerBunch;
    case 'Packung':
      return amount * 250;
    case 'Stück':
    case '':
      return amount * (entry.gramsPerPiece > 0 ? entry.gramsPerPiece : 0);
    default:
      return 0;
  }
}
