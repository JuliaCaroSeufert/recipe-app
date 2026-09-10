// Phase 4 — weekly-plan generator + persistence.
//
// The generator is a pure function (easy to reason about / test); everything
// that touches Supabase lives in the read/write helpers below. A plan is only
// persisted when the user confirms it — until then it lives in screen state.

import { createShoppingListForPlan } from './shopping';
import { ensureSession, supabase } from './supabase';
import type { MealPlan, MealPlanEntry, PlanFilters, Recipe } from './types';

/** Lightweight recipe shape the generator works with. */
export interface PlanRecipe {
  id: string;
  title: string;
  servings: number;
  kcal_per_serving: number | null;
  tags: string[]; // lower-cased tag names
}

export interface GeneratedPick {
  recipe: PlanRecipe;
  dayIndex: number;
  slotIndex: number;
}

/** Thrown when the filters cannot be satisfied; message is German, user-facing. */
export class PlanError extends Error {}

// --- reads ------------------------------------------------------------------

/** All recipes with their (lower-cased) tag names, for the generator. */
export async function listRecipesForPlanning(): Promise<PlanRecipe[]> {
  await ensureSession();
  const { data, error } = await supabase
    .from('recipes')
    .select('id,title,servings,kcal_per_serving,recipe_tags(tag:tags(name))');
  if (error) throw error;
  return (data ?? []).map((row: any) => ({
    id: row.id,
    title: row.title,
    servings: row.servings,
    kcal_per_serving: row.kcal_per_serving,
    tags: (row.recipe_tags ?? [])
      .map((rt: any) => rt.tag?.name)
      .filter(Boolean)
      .map((n: string) => n.toLowerCase()),
  }));
}

/** Distinct tag names in the user's catalog (for the filter UI). */
export async function listAllTags(): Promise<string[]> {
  await ensureSession();
  const { data, error } = await supabase
    .from('tags')
    .select('name')
    .order('name');
  if (error) throw error;
  return (data ?? []).map((t: any) => t.name as string);
}

export interface PlanWithEntries {
  plan: MealPlan;
  entries: (MealPlanEntry & { recipe: Pick<Recipe, 'id' | 'title' | 'kcal_per_serving' | 'servings'> })[];
}

/** The most recently created plan with its entries + recipe summaries, or null. */
export async function getLatestPlan(): Promise<PlanWithEntries | null> {
  await ensureSession();
  const { data, error } = await supabase
    .from('meal_plans')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  const plan = data as MealPlan;

  const { data: entryRows, error: entryError } = await supabase
    .from('meal_plan_entries')
    .select('*, recipe:recipes(id,title,kcal_per_serving,servings)')
    .eq('plan_id', plan.id)
    .order('day_index')
    .order('slot_index');
  if (entryError) throw entryError;

  return { plan, entries: (entryRows ?? []) as any };
}

// --- generator (pure) -------------------------------------------------------

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/**
 * Build a list of recipe picks for the whole plan.
 *
 * Rules honoured:
 *  - `maxKcalPerServing`: recipes above the limit (or without a kcal value) are
 *    dropped from the candidate pool.
 *  - `includeTags` / `excludeTags`: candidate must carry all include tags and
 *    none of the exclude tags.
 *  - `tagRules`: `min` guarantees at least N meals carry the tag; `max` caps it.
 *
 * Recipes may repeat when the candidate pool is smaller than the number of
 * meals, but unused recipes are always preferred for variety. Throws
 * `PlanError` (German message) when the constraints cannot be met.
 */
export function generatePlan(
  recipes: PlanRecipe[],
  filters: PlanFilters,
): GeneratedPick[] {
  const days = filters.days ?? 7;
  const mealsPerDay = filters.mealsPerDay ?? 1;
  const slots = days * mealsPerDay;

  const include = (filters.includeTags ?? []).map((t) => t.toLowerCase());
  const exclude = (filters.excludeTags ?? []).map((t) => t.toLowerCase());
  const rules = (filters.tagRules ?? []).map((r) => ({
    tag: r.tag.toLowerCase(),
    min: r.min,
    max: r.max,
  }));

  const candidates = recipes.filter((r) => {
    if (
      filters.maxKcalPerServing != null &&
      (r.kcal_per_serving == null || r.kcal_per_serving > filters.maxKcalPerServing)
    )
      return false;
    if (include.some((t) => !r.tags.includes(t))) return false;
    if (exclude.some((t) => r.tags.includes(t))) return false;
    return true;
  });

  if (candidates.length === 0)
    throw new PlanError(
      'Keine Rezepte passen zu den Filtern. Lockere die Filter oder füge Rezepte hinzu.',
    );

  const picks: PlanRecipe[] = [];
  const tagCount: Record<string, number> = {};
  const usedIds = new Set<string>();

  const maxFor = (tag: string) => rules.find((r) => r.tag === tag && r.max != null)?.max;

  const canAdd = (r: PlanRecipe) =>
    !r.tags.some((t) => {
      const max = maxFor(t);
      return max != null && (tagCount[t] ?? 0) + 1 > max;
    });

  const add = (r: PlanRecipe) => {
    picks.push(r);
    usedIds.add(r.id);
    for (const t of r.tags) tagCount[t] = (tagCount[t] ?? 0) + 1;
  };

  // Pick one candidate matching `predicate`, preferring unused recipes, then
  // allowing a repeat. Returns undefined when nothing addable matches.
  const pickOne = (predicate: (r: PlanRecipe) => boolean): PlanRecipe | undefined => {
    const pool = shuffle(candidates.filter((r) => predicate(r) && canAdd(r)));
    return pool.find((r) => !usedIds.has(r.id)) ?? pool[0];
  };

  // 1. Satisfy the min tag-rules first.
  for (const rule of rules) {
    if (rule.min == null) continue;
    while ((tagCount[rule.tag] ?? 0) < rule.min) {
      if (picks.length >= slots)
        throw new PlanError(
          'Die Mindest-Regeln passen nicht in die Anzahl der Mahlzeiten. Erhöhe Tage/Mahlzeiten oder senke die Mindestwerte.',
        );
      const cand = pickOne((r) => r.tags.includes(rule.tag));
      if (!cand)
        throw new PlanError(
          `Nicht genug Rezepte mit Tag „${rule.tag}“ (mindestens ${rule.min} nötig).`,
        );
      add(cand);
    }
  }

  // 2. Fill the remaining slots with any addable candidate.
  while (picks.length < slots) {
    const cand = pickOne(() => true);
    if (!cand)
      throw new PlanError(
        'Nicht genug passende Rezepte, um alle Mahlzeiten zu füllen. Lockere die Filter oder füge Rezepte hinzu.',
      );
    add(cand);
  }

  // 3. Lay the flat pick list out over days × slots.
  return picks.map((recipe, i) => ({
    recipe,
    dayIndex: Math.floor(i / mealsPerDay),
    slotIndex: i % mealsPerDay,
  }));
}

// --- writes -----------------------------------------------------------------

export interface ConfirmPlanInput {
  title: string;
  startDate?: string | null;
  days: number;
  mealsPerDay: number;
  servings: number; // persons for the whole week
  filters: PlanFilters;
  picks: GeneratedPick[];
}

/**
 * Persist a confirmed plan and its entries, then build the aggregated shopping
 * list from it. Returns the new plan id.
 */
export async function confirmPlan(input: ConfirmPlanInput): Promise<string> {
  const userId = await ensureSession();

  const { data: plan, error } = await supabase
    .from('meal_plans')
    .insert({
      user_id: userId,
      title: input.title.trim() || 'Wochenplan',
      start_date: input.startDate ?? null,
      days: input.days,
      meals_per_day: input.mealsPerDay,
      servings: input.servings,
      status: 'confirmed',
      filters: input.filters,
    })
    .select('id')
    .single();
  if (error) throw error;
  const planId = (plan as { id: string }).id;

  const rows = input.picks.map((p) => ({
    plan_id: planId,
    recipe_id: p.recipe.id,
    user_id: userId,
    day_index: p.dayIndex,
    slot_index: p.slotIndex,
  }));
  if (rows.length > 0) {
    const { error: entryError } = await supabase
      .from('meal_plan_entries')
      .insert(rows);
    if (entryError) throw entryError;
  }

  await createShoppingListForPlan(planId, input.servings, input.picks);
  return planId;
}
