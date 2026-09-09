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
| 3 | Instagram import (share-intent → caption → Gemini) | ⬜ |
| 4 | Weekly-plan generator with filters (days, meals/day, tag rules, kcal limit), persons set once, confirm | ⬜ |
| 5 | Shopping list: aggregate ingredient quantities across recipes, scale by persons, group by category | ⬜ |
| 6 | REWE ordering (unofficial API) + shopping-list export fallback | ⬜ |

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

## Project layout

```
src/
  app/                     expo-router routes
    (tabs)/                Rezepte · Wochenplan · Einkauf
    recipe/[id].tsx        recipe detail
    recipe/new.tsx         create / edit form (?id=<uuid> to edit)
  components/ui.tsx         Screen, Field, Button, Card, Empty
  lib/
    supabase.ts            client + anonymous session bootstrap
    types.ts               domain types mirroring the SQL schema
    parse.ts               ingredient-line parser ("200 g Feta, gewürfelt")
    recipes.ts             recipe CRUD + ingredient/tag catalog
  lib/
    extract.ts             pick a PDF + call the extract-recipe function
    draft.ts               import → review-form hand-off
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
