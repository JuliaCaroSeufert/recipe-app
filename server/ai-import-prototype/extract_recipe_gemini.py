"""
Essensplan – KI-Rezept-Import, KOSTENLOSE Variante: Google Gemini.

Gleiche Ausgabe wie die Claude-Variante, aber über die Gratis-Stufe von
Google AI Studio – es wird KEINE Kreditkarte benötigt, nur ein Google-Konto.

So bekommst du einen kostenlosen Schlüssel:
    1. https://aistudio.google.com/apikey öffnen (mit Google-Konto anmelden)
    2. "Create API key" / "API-Schlüssel erstellen" klicken und kopieren

Nutzung (Windows PowerShell):
    $env:GEMINI_API_KEY = "DEIN_GEMINI_KEY"
    pip install -r requirements.txt
    python extract_recipe_gemini.py sample_caption.txt

Nutzung (macOS/Linux):
    export GEMINI_API_KEY=...
    python extract_recipe_gemini.py sample_caption.txt
"""

import json
import os
import sys

from google import genai
from google.genai import types

import recipe_spec

# Kostenloses Flash-Modell. Bei Bedarf per GEMINI_MODEL überschreibbar.
# Hinweis: Google rotiert die Flash-Versionen; wenn ein 404 "no longer
# available" kommt, nenne der Fehler das neue Modell – dann einfach
# $env:GEMINI_MODEL = "gemini-X.Y-flash" setzen.
MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")


def _strip_code_fence(text: str) -> str:
    """Entfernt evtl. ```json ... ``` Umrandung, falls doch mal welche kommt."""
    t = text.strip()
    if t.startswith("```"):
        t = t.split("\n", 1)[1] if "\n" in t else t
        if t.endswith("```"):
            t = t[: -3]
        if t.lstrip().startswith("json"):
            t = t.lstrip()[4:]
    return t.strip()


def extract_recipe(caption: str, url: str | None = None) -> dict:
    """Ruft Gemini auf und gibt das Rezept als dict zurück."""
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    client = genai.Client(api_key=api_key)
    user_content = caption if not url else f"Quelle: {url}\n\n{caption}"

    response = client.models.generate_content(
        model=MODEL,
        contents=user_content,
        config=types.GenerateContentConfig(
            system_instruction=recipe_spec.SYSTEM_PROMPT + "\n\n" + recipe_spec.json_shape_hint(),
            response_mime_type="application/json",
            temperature=0.2,
        ),
    )
    recipe = json.loads(_strip_code_fence(response.text))
    recipe["_meta"] = {
        "provider": "gemini",
        "model": MODEL,
        "note": "kostenlose AI-Studio-Stufe (Rate-Limits beachten)",
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
        print("Keine Caption übergeben. Beispiel: python extract_recipe_gemini.py sample_caption.txt",
              file=sys.stderr)
        sys.exit(1)
    result = extract_recipe(caption)
    print(json.dumps(result, ensure_ascii=False, indent=2))
