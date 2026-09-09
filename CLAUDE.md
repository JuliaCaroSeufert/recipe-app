@AGENTS.md

# FamilienRezepte — build notes

Android-first recipe app. Stack: Expo (React Native) + TypeScript, Supabase
(Postgres + Auth + Storage + Edge Functions), Gemini free tier for
PDF/Instagram recipe extraction (Groq free tier fallback). REWE ordering via
unofficial API is the last phase; ship a shopping-list export as the fallback.

Phase status and setup steps live in `README.md`. Full schema (all phases) is
`supabase/migrations/0001_init.sql` — extend it there, keep `src/lib/types.ts`
in sync.

Conventions:
- User-facing strings are German. Code, comments, commits stay English.
- Data access goes through `src/lib/*.ts`; screens never call `supabase`
  directly except to read `isSupabaseConfigured`.
- `npx tsc --noEmit` and `npx expo export --platform android` must both pass
  before a commit.
- expo-router 57 vendors react-navigation internally; import `Tabs`/`Stack`
  from `expo-router`. Standard JS tab bar (works in Expo Go), not native tabs.
