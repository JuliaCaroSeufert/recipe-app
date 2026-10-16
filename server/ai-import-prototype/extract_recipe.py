"""
Essensplan – KI-Rezept-Import, Variante: Anthropic Claude.

Nimmt den Beschreibungstext (Caption) eines Rezepts und lässt Claude Haiku 5.5
daraus ein strukturiertes Rezept im App-Format bauen (Zutaten mit Kategorie +
Gemüse-Markierung, Schritte, geschätzte Makro- UND Mikronährwerte).

Hinweis: Claude braucht Guthaben auf dem Anthropic-Konto. Wenn du KEINE
Zahlungsdaten hinterlegen willst, nutze stattdessen die kostenlose Gemini-
Variante: `python extract_recipe_gemini.py sample_caption.txt` (siehe README).

Nutzung:
    export ANTHROPIC_API_KEY=sk-ant-...        (Windows PowerShell: $env:ANTHROPIC_API_KEY = "...")
    pip install -r requirements.txt
    python extract_recipe.py sample_caption.txt
"""

import json
import os
import sys

import anthropic

import recipe_spec

MODEL = "claude-haiku-5-5"  # günstigstes Claude-Modell, gut für Extraktion


def extract_recipe(caption: str, url: str | None = None) -> dict:
    """Ruft Claude Haiku 5.5 auf und gibt das Rezept als dict zurück."""
    # Nicht-workspace-gebundene API-Keys brauchen die Workspace-ID als Header.
    workspace = os.environ.get("ANTHROPIC_WORKSPACE_ID")
    client = anthropic.Anthropic(
        default_headers={"anthropic-workspace-id": workspace} if workspace else None,
    )
    user_content = caption if not url else f"Quelle: {url}\n\n{caption}"
    response = client.messages.create(
        model=MODEL,
        max_tokens=4000,
        system=recipe_spec.SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_content}],
        output_config={
            "format": {"type": "json_schema", "schema": recipe_spec.RECIPE_SCHEMA}
        },
    )
    text = next(b.text for b in response.content if b.type == "text")
    recipe = json.loads(text)

    usage = response.usage
    cost = (usage.input_tokens / 1_000_000 * 0.10
            + usage.output_tokens / 1_000_000 * 0.50)
    recipe["_meta"] = {
        "provider": "claude",
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
