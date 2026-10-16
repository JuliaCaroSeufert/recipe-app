"""Gemeinsame Rezept-Definition für alle Anbieter (Claude, Gemini, ...).

Enthält das Zielschema, die erlaubten Aufzählungswerte und den Prompt – damit
jeder Anbieter-Adapter exakt dasselbe App-kompatible Rezept erzeugt.
"""

# Aufzählungswerte müssen zum App-Modell passen (lib/models/*.dart).
CATEGORIES = [
    "produce",    # Obst & Gemüse
    "legumes",    # Hülsenfrüchte
    "dairy",      # Molkerei & Eier
    "meatFish",   # Fleisch & Fisch
    "pantry",     # Vorrat & Trockenwaren
    "spices",     # Gewürze & Öle
    "frozen",     # Tiefkühl
    "other",      # Sonstiges
]
UNITS = ["", "g", "ml", "Stück", "EL", "TL", "Prise", "Dose", "Bund", "Packung", "Tasse"]

NUTRIENT_KEYS = [
    "kcal", "protein", "carbs", "fat", "fiber",
    "iron", "calcium", "magnesium", "potassium", "zinc",
    "vitaminC", "vitaminA", "folate",
]

# Striktes JSON-Schema (für Anbieter, die Schemas unterstützen, z. B. Claude).
RECIPE_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": [
        "title", "emoji", "description", "prepMinutes", "baseServings",
        "suitableFor", "tags", "isVegetarian", "isVegan", "batchFriendly",
        "ingredients", "steps", "nutritionPerServing",
    ],
    "properties": {
        "title": {"type": "string"},
        "emoji": {"type": "string"},
        "description": {"type": "string"},
        "prepMinutes": {"type": "integer"},
        "baseServings": {"type": "integer"},
        "suitableFor": {
            "type": "array",
            "items": {"type": "string", "enum": ["lunch", "dinner"]},
        },
        "tags": {"type": "array", "items": {"type": "string"}},
        "isVegetarian": {"type": "boolean"},
        "isVegan": {"type": "boolean"},
        "batchFriendly": {"type": "boolean"},
        "ingredients": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["name", "amount", "unit", "category", "produceKey"],
                "properties": {
                    "name": {"type": "string"},
                    "amount": {"type": "number"},
                    "unit": {"type": "string", "enum": UNITS},
                    "category": {"type": "string", "enum": CATEGORIES},
                    "produceKey": {"type": ["string", "null"]},
                },
            },
        },
        "steps": {"type": "array", "items": {"type": "string"}},
        "nutritionPerServing": {
            "type": "object",
            "additionalProperties": False,
            "required": NUTRIENT_KEYS,
            "properties": {k: {"type": "number"} for k in NUTRIENT_KEYS},
        },
    },
}

SYSTEM_PROMPT = """\
Du bist ein Ernährungs- und Rezept-Assistent für die App "Essensplan".
Du bekommst den Beschreibungstext (Caption) eines Koch-Reels/-Posts und baust
daraus EIN strukturiertes Rezept.

Regeln:
- Alle für Nutzer sichtbaren Texte auf DEUTSCH (Titel, Zutaten, Schritte).
- Mengen beziehen sich auf baseServings Portionen. Erkenne Portionen und
  Zubereitungszeit aus dem Text; wenn unklar: baseServings=2, prepMinutes=30.
- Zutaten-Kategorie aus der erlaubten Liste wählen. Für Gemüse UND
  Hülsenfrüchte setze produceKey auf den kanonischen Namen (z. B. "Karotte",
  "Kichererbse", "Spinat"); bei allem anderen produceKey=null. Alltags-Stärke
  wie Kartoffel/Reis/Nudeln ist KEIN produceKey.
- Schätze die Nährwerte PRO PORTION so gut es geht (Makros + Mikros) aus den
  Zutaten und Mengen. Lieber eine fundierte Schätzung als Nullen. Wenn eine
  Menge fehlt, setze amount=0, schätze die Nährwerte trotzdem plausibel.
- isVegan/isVegetarian aus den Zutaten ableiten. batchFriendly=true NUR wenn
  sich das Gericht gekocht 4–5 Tage im Kühlschrank hält und gut wieder
  aufwärmbar ist (Eintöpfe, Currys, Dal, Suppen, Chili, Bolognese-/Tomaten-
  saucen, Aufläufe). Frische Bowls, Blattsalate, Ofengemüse, knusprige oder
  panierte Gerichte und alles mit rohem Blattgrün/Avocado = false.
- Wähle ein passendes Emoji. Erfinde keine Schritte, die nicht im Text stehen;
  fasse den Text nur sauber zusammen.
"""


def json_shape_hint() -> str:
    """Textuelle Schemabeschreibung für Anbieter ohne striktes Schema (Gemini)."""
    return (
        "Antworte AUSSCHLIESSLICH mit einem JSON-Objekt (kein Text drumherum, "
        "kein Markdown) mit genau diesen Feldern:\n"
        "- title (string), emoji (string), description (string)\n"
        "- prepMinutes (integer), baseServings (integer)\n"
        "- suitableFor: Array aus 'lunch' und/oder 'dinner'\n"
        "- tags: Array von Strings\n"
        "- isVegetarian (bool), isVegan (bool), batchFriendly (bool)\n"
        "- ingredients: Array von Objekten {name (string), amount (number), "
        f"unit (einer von: {UNITS}), category (einer von: {CATEGORIES}), "
        "produceKey (string oder null)}\n"
        "- steps: Array von Strings\n"
        "- nutritionPerServing: Objekt mit genau diesen Zahlenfeldern: "
        f"{NUTRIENT_KEYS}\n"
        "Keine zusätzlichen Felder."
    )
