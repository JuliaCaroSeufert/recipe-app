# KI-Import – Mini-Prototyp

Kleinster möglicher Schritt zum KI-Import: Du gibst den **Beschreibungstext**
eines Rezepts rein, **Claude Haiku 5.5** macht daraus ein fertiges Rezept im
Essensplan-Format (Zutaten mit Kategorie + Gemüse-Markierung, Schritte,
geschätzte Makro- **und** Mikronährwerte).

Noch **ohne** Scraping und **ohne** Video – damit du zuerst Qualität und
Aufwand siehst, bevor wir die volle Pipeline (Link teilen → Video → Rezept)
bauen.

## 0. Code holen & Branch auschecken

Der Code liegt auf dem Branch **`claude/gallant-bohr-s6ur6z`** (der Name ist
automatisch vergeben). Zum Kopieren:

```bash
# Noch nicht geklont? Dann:
git clone https://github.com/JuliaCaroSeufert/recipe-app.git
cd recipe-app

# Branch auschecken und neuesten Stand holen:
git fetch origin
git checkout claude/gallant-bohr-s6ur6z
git pull origin claude/gallant-bohr-s6ur6z
```

Falls du das Repo schon hast, reichen die letzten drei Zeilen (im Projektordner).

## Ausprobieren (ca. 5 Minuten)

1. **Anthropic-Konto + API-Schlüssel** anlegen: <https://console.anthropic.com> →
   *API Keys* → *Create Key*. Ein paar Euro Guthaben reichen für tausende Rezepte.
2. Python 3.10+ vorausgesetzt, dann:
   ```bash
   cd server/ai-import-prototype
   python -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   export ANTHROPIC_API_KEY=sk-ant-...        # dein Schlüssel
   python extract_recipe.py sample_caption.txt
   ```
3. Du bekommst das fertige Rezept als JSON ausgegeben – inkl. `_meta` mit den
   tatsächlichen Tokenkosten dieses Aufrufs (zum Gegenrechnen).

Eigenen Text testen: Caption kopieren und reingeben, z. B.
```bash
pbpaste | python extract_recipe.py -          # macOS
```

## Was es kostet

Ein Aufruf nutzt **Claude Haiku 5.5** ($0,10 pro 1 Mio. Eingabe-Tokens,
$0,50 pro 1 Mio. Ausgabe-Tokens). Ein typisches Rezept liegt bei grob
3.000 Eingabe- + 1.000 Ausgabe-Tokens ≈ **$0,0008 pro Rezept** (unter einem
Zehntel-Cent). Das Feld `_meta.estimated_cost_usd` zeigt dir den echten Wert
pro Lauf.

## Wenn dir das Ergebnis gefällt – die nächsten Ausbaustufen

1. **Als Server-Endpoint**: dieselbe Funktion in eine kleine Cloud-Funktion
   (z. B. Cloudflare Worker / Supabase Edge Function) packen; die App schickt
   den geteilten Text hin und speichert das zurückgegebene Rezept. Der
   API-Schlüssel bleibt serverseitig, nie in der App.
2. **Volle Pipeline** (optional, teurer): aus einem geteilten **Link**
   automatisch die Caption holen (Scraping-Dienst) und reine Video-Reels per
   **Whisper** (Audio) + OCR (Text im Bild) ergänzen, bevor Claude strukturiert.

Siehe die Diskussion im Projektverlauf für Kosten/AGB-Abwägung der vollen
Pipeline.

## Hinweis

Dieser Ordner ist eigenständig (Python) und unabhängig von der Flutter-App.
Er wird nicht mitgebaut und beeinflusst `flutter analyze`/`flutter test` nicht.
