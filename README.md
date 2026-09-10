# FamilienRezepte

Android recipe app: import recipes from PDF and Instagram, auto-build a weekly
meal plan with filters, generate an aggregated shopping list, and (later) order
the ingredients from REWE.

Built with **Expo (React Native) + TypeScript** and **Supabase** (Postgres,
Auth, Storage, Edge Functions). Recipe extraction from PDF/Instagram uses the
**Google Gemini API free tier** (Groq free tier as fallback).

## Status

| Phase | Scope | State |
| ----- | ----- | ----- |
| 1 | App shell, Supabase schema, manual recipe CRUD (ingredients, steps, tags, kcal, servings) | ✅ done |
| 2 | PDF import → Gemini extraction → review screen | ✅ done (needs deploy, see below) |
| 3 | Instagram import (paste caption or screenshot → Gemini) | ✅ done |
| 4 | Weekly-plan generator with filters (days, meals/day, tag rules, kcal limit), persons set once, confirm | ✅ done |
| 5 | Shopping list: aggregate ingredient quantities across recipes, scale by persons, group by category | ✅ done |
| 6 | REWE handoff (deep-link product search per item) + text export fallback | ✅ done |

## Prerequisites

- Node 20+ and npm
- A free [Supabase](https://supabase.com) project
- The **Expo Go** app on your Android phone (for development)

## Setup

1. **Install dependencies**

   ```bash
   npm install
   ```

2. **Create the Supabase project** and apply the schema

   - New project at https://supabase.com/dashboard
   - Open **SQL Editor**, paste the contents of
     [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql),
     run it
   - **Authentication → Providers → Anonymous sign-ins**: enable
     (the app signs in anonymously so Row Level Security works without a
     login screen; email auth can be added later without schema changes)

3. **Environment variables**

   ```bash
   cp .env.example .env
   ```

   Fill in `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY`
   from **Project Settings → API**. Both are safe to ship in a client app.

4. **Run**

   ```bash
   npx expo start
   ```

   Scan the QR code with Expo Go on your Android phone.

## Phase 2 — deploy the PDF import function

The "PDF importieren" button calls a Supabase Edge Function
(`supabase/functions/extract-recipe`) that runs Google Gemini. One-time setup:

1. **Gemini API key** — create a free key at
   https://aistudio.google.com/apikey (free tier: no billing needed).

2. **Link the Supabase CLI to your project**

   ```bash
   npx supabase login
   npx supabase link --project-ref <your-project-ref>
   ```

   The project ref is the subdomain of your Supabase URL
   (`https://<ref>.supabase.co`).

3. **Store the key as a function secret**

   ```bash
   npx supabase secrets set GEMINI_API_KEY=<your-key>
   # optional: pick a different model (default gemini-2.5-flash)
   # npx supabase secrets set GEMINI_MODEL=gemini-2.5-flash
   ```

4. **Deploy**

   ```bash
   npx supabase functions deploy extract-recipe
   ```

5. In the app: **Rezepte → PDF importieren**, pick a recipe PDF. The extracted
   recipe opens in the review form ("Rezept prüfen") — fix anything, then save.

Notes:
- Free-tier inputs may be used by Google to improve their products. Fine for
  personal recipes; don't feed it anything sensitive.
- On the free tier a daily request limit applies; the function surfaces a
  "Tageslimit erreicht" message when Gemini returns HTTP 429.
- Max PDF size ~10 MB (Gemini inline-data limit).

## Phase 3 — Instagram import

Uses the same `extract-recipe` edge function as the PDF import, so no extra
setup beyond the Phase 2 deploy. Instagram blocks scraping post captions
without a login, so the import takes the recipe from content you already have:

- **Rezepte → Instagram importieren**
  - **Aus Text lesen** — open the post, copy the caption text, paste it. Gemini
    strips hashtags/emojis and extracts ingredients + steps.
  - **Screenshot importieren** — pick a screenshot of the recipe from your
    gallery; it is sent to Gemini as an image.
- Optionally paste the post link; it is stored as the recipe's source.
- The result opens in the same "Rezept prüfen" review form as the PDF import.

A native Android share-intent target ("share to FamilienRezepte") needs a
custom dev build (not Expo Go) and can be added later without changing this flow.

## Phase 4 + 5 — weekly plan & shopping list

No extra setup — both run entirely against the Supabase schema from Phase 1.

1. **Wochenplan** tab → set persons (once for the week), days, meals/day, an
   optional max kcal/serving, tag include/exclude filters and tag rules
   (e.g. "mindestens 3× bake and dump"). Tap **Plan generieren** for a preview,
   regenerate until happy, then **Bestätigen & Einkaufsliste erstellen**.
2. **Einkauf** tab → the confirmed plan's ingredients, summed across all recipes
   and scaled to the person count, grouped by category. Tap to tick items off,
   or **Als Text teilen** to export the list (REWE ordering follows in Phase 6).

The generator prefers unused recipes for variety and only repeats a recipe when
the filtered pool is smaller than the number of meals. It reports a clear German
message when the filters cannot be satisfied (e.g. too few recipes carrying a
required tag).

## Phase 6 — REWE ordering

**Why it's a handoff, not one-tap checkout:** REWE has no public ordering API.
The endpoints behind `shop.rewe.de` are login-, cookie- and bot-protected
(Akamai) and change without notice, so a headless "fill the cart and pay" flow
can't be built reliably — and automating it would breach REWE's terms. So the
app hands the list to REWE the robust way and lets REWE own the account,
market, delivery address and payment.

- **Einkauf → Bei REWE bestellen**
  - **Ganze Liste bei REWE öffnen** / per-item **Bei REWE suchen** — opens a
    REWE product-search universal link (the REWE app if installed, else
    `shop.rewe.de` in the browser) with the ingredient pre-filled. Pick the
    product, add to cart, repeat, then check out inside REWE.
  - **Als bestellt markieren** — flips the list to `ordered`.
  - **Liste als Text teilen** — the plain-text export fallback.

No setup or keys required. A tighter integration (product matching with prices
via the private mobile API) is possible later but is inherently brittle; the
`ingredients.rewe_product_id` / `shopping_list_items.rewe_product_id` columns
are already reserved for it.

## Project layout

```
src/
  app/                     expo-router routes
    (tabs)/                Rezepte · Wochenplan · Einkauf
    recipe/[id].tsx        recipe detail
    recipe/new.tsx         create / edit form (?id=<uuid> to edit)
    recipe/instagram.tsx   Instagram import (paste caption / pick screenshot)
    rewe.tsx               REWE order handoff (per-item / whole-list search)
  components/ui.tsx         Screen, Field, Button, Card, Empty
  lib/
    supabase.ts            client + anonymous session bootstrap
    types.ts               domain types mirroring the SQL schema
    parse.ts               ingredient-line parser ("200 g Feta, gewürfelt")
    recipes.ts             recipe CRUD + ingredient/tag catalog
  lib/
    extract.ts             PDF / Instagram caption / screenshot → extract fn
    draft.ts               import → review-form hand-off
    plan.ts                weekly-plan generator (pure) + plan persistence
    shopping.ts            cross-recipe quantity aggregation + list access
    rewe.ts                REWE product-search deep links + order status
supabase/
  migrations/0001_init.sql full schema (all phases) + RLS
  functions/extract-recipe stateless Gemini extraction (Deno)
  config.toml              CLI config (extract-recipe: verify_jwt=false)
```

## Data model (short)

- `recipes` — title, servings the recipe is written for, `kcal_per_serving`,
  `prep_minutes`, `steps` (jsonb array), `source_type` (`manual`/`pdf`/`instagram`)
- `ingredients` — canonical per-user catalog; `category` for shopping-list
  grouping, `density_g_per_ml` and `rewe_product_id` reserved for later phases
- `recipe_ingredients` — quantity + unit + note + `raw_text`, linked to a
  catalog ingredient (this link is what makes cross-recipe aggregation possible)
- `tags` + `recipe_tags` — free-form, lower-cased (`bake and dump`, `unter 500 kcal`)
- `meal_plans` / `meal_plan_entries` — weekly plan; `servings` = persons for the
  whole week, `filters` = the generator config used
- `shopping_lists` / `shopping_list_items` — created on plan confirmation

Every table is owner-scoped via RLS (`user_id = auth.uid()`).
