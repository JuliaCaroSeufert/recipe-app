"""
Essensplan – Mini-Prototyp für den KI-Rezept-Import.

Nimmt den Beschreibungstext (Caption) eines Instagram-Rezepts und lässt
Claude Haiku 5.5 daraus ein strukturiertes Rezept im App-Format bauen –
inklusive geschätzter Nährwerte, Zutaten-Kategorien und Gemüse-Markierung.

Dies ist bewusst der kleinste Schritt: nur Caption-Text + Claude, KEIN
Scraping und KEINE Video-Transkription. Damit kannst du Qualität und Aufwand
beurteilen, bevor wir die volle Pipeline bauen.

Nutzung:
    export ANTHROPIC_API_KEY=sk-ant-...
    pip install -r requirements.txt
    python extract_recipe.py sample_caption.txt
    # oder:  pbpaste | python extract_recipe.py -
"""

import json
import sys

import anthropic

MODEL = "claude-haiku-5-5"  # günstigstes Claude-Modell, gut für Extraktion

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

_NUTRIENT_KEYS = [
    "kcal", "protein", "carbs", "fat", "fiber",
    "iron", "calcium", "magnesium", "potassium", "zinc",
    "vitaminC", "vitaminA", "folate",
]

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
            "required": _NUTRIENT_KEYS,
            "properties": {k: {"type": "number"} for k in _NUTRIENT_KEYS},
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
- isVegan/isVegetarian aus den Zutaten ableiten. batchFriendly=true nur wenn
  das Gericht sich gut vorkochen/aufwärmen lässt (Eintöpfe, Currys, Suppen,
  Aufläufe), sonst false.
- Wähle ein passendes Emoji. Erfinde keine Schritte, die nicht im Text stehen;
  fasse den Text nur sauber zusammen.
"""


def extract_recipe(caption: str, url: str | None = None) -> dict:
    """Ruft Claude Haiku 5.5 auf und gibt das Rezept als dict zurück."""
    client = anthropic.Anthropic()
    user_content = caption if not url else f"Quelle: {url}\n\n{caption}"
    response = client.messages.create(
        model=MODEL,
        max_tokens=4000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_content}],
        output_config={"format": {"type": "json_schema", "schema": RECIPE_SCHEMA}},
    )
    text = next(b.text for b in response.content if b.type == "text")
    recipe = json.loads(text)

    # Grobe Kostenschätzung dieses Aufrufs (nur zur Info).
    usage = response.usage
    cost = (usage.input_tokens / 1_000_000 * 0.10
            + usage.output_tokens / 1_000_000 * 0.50)
    recipe["_meta"] = {
        "model": MODEL,
        "input_tokens": usage.input_tokens,
        "output_tokens": usage.output_tokens,
        "estimated_cost_usd": round(cost, 5),
    }
    return recipe


def _read_input() -> str:
    if len(sys.argv) > 1 and sys.argv[1] != "-":
        with open(sys.argv[1], encoding="utf-8") as f:
            return f.read()
    return sys.stdin.read()


if __name__ == "__main__":
    caption = _read_input().strip()
    if not caption:
        print("Keine Caption übergeben. Beispiel: python extract_recipe.py sample_caption.txt",
              file=sys.stderr)
        sys.exit(1)
    result = extract_recipe(caption)
    print(json.dumps(result, ensure_ascii=False, indent=2))
