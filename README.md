# Essensplan 🥗

Ein **Wochenplaner für Mittag- und Abendessen** fürs Handy – komplett
**offline**, mit Rezeptvorschlägen, Nährwert-Optimierung, Batch-Cooking,
Bestell-Tagen, Einkaufsliste, Instagram-Import und Wochen-Recycling.

Gebaut mit **Flutter (Dart)**. Alle Daten liegen lokal auf dem Gerät
(SQLite) – kein Login, kein Server, keine laufenden Kosten.

> Hinweis: Der Projektordner heißt historisch `recipe-app`, die App selbst
> ist `essensplan` (siehe `pubspec.yaml`).

## Funktionen

| Wunsch | Umsetzung |
| --- | --- |
| Woche für Mittag + Abendessen planen | Tab **Woche**: 7 Tage mit je einem Mittag- und Abend-Slot |
| Rezepte mit Zutaten vorgeschlagen bekommen | **„Woche planen"** erzeugt automatisch einen Vorschlag |
| Batch-Cooking für X Tage | Im Planer einstellbar (einmal kochen → mehrere Mahlzeiten als „Reste") |
| Tage zum Bestellen auswählen | Im Planer pro Mahlzeit als „Bestellen" markierbar |
| Personenanzahl festlegen | In **Einstellungen** und im Planer; skaliert Mengen & Nährwerte |
| Abneigungen („mag ich nicht") | In **Einstellungen**; betroffene Rezepte werden übersprungen |
| Schnelle & leckere Rezepte schon drin | 24 mitgelieferte Rezepte (Filter „Schnell", „Vegan" …) |
| Einkaufsliste | Tab **Einkauf**: automatisch aus dem Plan, gruppiert, abhakbar, kopierbar |
| Rezepte aus Instagram importieren | **Teilen** aus Instagram → Essensplan (oder **Rezepte → +**): Text wird automatisch in ein Rezept umgewandelt |
| Wochen recyceln | Tab **Woche → Archiv**: alte Woche z. B. in 3 Monaten erneut einplanen |
| Makro- **und** Mikronährstoffe tracken & optimieren | Jedes Rezept hat Nährwerte; der Planer füllt gezielt Nährstofflücken |
| ≥ 20 Gemüse/Hülsenfrüchte pro Woche | Vielfalts-Ziel im Plan; der Generator maximiert verschiedene Sorten |

## Auf dem Handy starten

1. **Flutter installieren** (einmalig): <https://docs.flutter.dev/get-started/install>
2. Im Projektordner die Pakete holen:
   ```bash
   flutter pub get
   ```
3. Handy per USB anschließen (Android: USB-Debugging aktivieren) **oder** einen
   Emulator starten, dann:
   ```bash
   flutter run
   ```
4. Installierbare Android-App bauen:
   ```bash
   flutter build apk --release
   # Ergebnis: build/app/outputs/flutter-apk/app-release.apk
   ```

Zum schnellen Ausprobieren im Browser: `flutter run -d chrome`
(Datenhaltung ist für das Gerät gedacht; der Browser dient nur der Vorschau).

## Entwicklung

```bash
flutter analyze   # statische Analyse – muss sauber sein
flutter test      # Unit-Tests der Logik (Generator, Nährwerte, Einkauf, Import)
```

### Projektstruktur

```
lib/
  models/      Datenmodelle (Recipe, Nutrition, WeekPlan, Household …)
  data/        Seed-Rezepte + SQLite-Repository
  logic/       reine, getestete Logik:
               plan_generator · nutrition_calc · shopping_list · instagram_parse
  state/       AppState (ChangeNotifier) – Single Source of Truth
  screens/     UI: week · recipes · shopping · settings · archive
  widgets/     wiederverwendbare Widgets (Nährwert-Balken, Vielfalts-Fortschritt)
  utils/       Datums-Helfer (deutsche Formatierung)
test/          Logik-Tests
```

## Technik-Entscheidungen

- **Flutter**: ein Code für Android + iOS, schnelle Iteration, großes Ökosystem.
- **Offline-first mit SQLite** (`sqflite`): kein Backend nötig; Entities werden
  als JSON gespeichert. Cloud-Sync (z. B. Supabase/PowerSync) ließe sich später
  ohne Datenmodell-Bruch ergänzen.
- **Nährwerte**: kuratierte Werte pro Rezept (angelehnt an USDA/DACH-
  Referenzwerte), damit alles offline funktioniert. Neue Zutaten könnten später
  per USDA-FoodData-Central-API ergänzt werden.
- **Instagram-Import**: per **Teilen-Menü** (`receive_sharing_intent`) – in
  Instagram die Beschreibung markieren und über „Teilen" an Essensplan senden,
  kein Kopieren nötig. Ein geteilter Rezepttext wird direkt erkannt; wird nur
  der Reel-**Link** geteilt, gibt Instagram die Beschreibung nicht mit (die App
  weist darauf hin). Bewusst **kein automatisches Scrapen** fremder Posts:
  Instagrams API deckt sie nicht ab und Scraping verstößt gegen die AGB.

### KI-Import (Gemini, optional & kostenlos)

Für automatisch erkannte Rezepte (inkl. geschätzter Nährwerte) kannst du einen
**kostenlosen Google-Gemini-Schlüssel** hinterlegen:

1. Gratis-Schlüssel holen: <https://aistudio.google.com/apikey> (nur Google-Konto,
   keine Kreditkarte).
2. In der App: **Einstellungen → KI-Import (Gemini)** → Schlüssel einfügen,
   speichern. Er bleibt nur lokal auf dem Gerät.
3. Danach erscheint im Import („Rezepte → + → Aus Instagram importieren" bzw.
   beim Teilen) der Button **„Mit KI erkennen"**; geteilte Captions werden
   automatisch verarbeitet. Ohne Schlüssel greift weiter die lokale
   Offline-Erkennung.

Ein Prototyp/Playground dazu liegt unter `server/ai-import-prototype/`
(Python; Gemini gratis, Claude als Alternative).

### Teilen auf iOS einrichten

Android funktioniert sofort (Intent-Filter ist in `AndroidManifest.xml`
konfiguriert). Für iOS braucht `receive_sharing_intent` zusätzlich eine **Share
Extension** und eine **App Group** im Xcode-Projekt – siehe die
Paket-Doku unter <https://pub.dev/packages/receive_sharing_intent>. Ohne diese
Schritte baut die iOS-App normal, empfängt aber keine geteilten Inhalte.
