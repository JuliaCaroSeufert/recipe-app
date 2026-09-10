// Phase 5 — aggregated shopping list.
//
// When a plan is confirmed we walk every meal, scale each recipe's ingredients
// to the week's person count, and sum identical ingredients across recipes
// (matching on the canonical ingredient + unit — this is why recipe lines are
// linked to the ingredient catalog). The result is one row per ingredient/unit.

import { ensureSession, supabase } from './supabase';
import type { Ingredient, ShoppingListItem, Unit } from './types';
import type { GeneratedPick } from './plan';

// --- aggregation ------------------------------------------------------------

interface AggregatedItem {
  ingredient_id: string;
  unit: Unit;
  total_quantity: number | null; // null when every source line had no quantity
}

/**
 * Aggregate the ingredient quantities needed for a set of meal picks, scaled
 * from each recipe's own serving count to `persons`. Pure apart from the single
 * DB read of the recipes' ingredient lines.
 */
export async function aggregateIngredients(
  persons: number,
  picks: GeneratedPick[],
): Promise<AggregatedItem[]> {
  await ensureSession();

  // How many times each recipe appears in the plan (a recipe may repeat).
  const occurrences = new Map<string, number>();
  const recipeServings = new Map<string, number>();
  for (const p of picks) {
    occurrences.set(p.recipe.id, (occurrences.get(p.recipe.id) ?? 0) + 1);
    recipeServings.set(p.recipe.id, p.recipe.servings || 1);
  }
  const recipeIds = [...occurrences.keys()];
  if (recipeIds.length === 0) return [];

  const { data, error } = await supabase
    .from('recipe_ingredients')
    .select('recipe_id,ingredient_id,quantity,unit')
    .in('recipe_id', recipeIds);
  if (error) throw error;

  // key = ingredient_id | unit
  const map = new Map<string, AggregatedItem & { hasQuantity: boolean }>();
  for (const row of (data ?? []) as any[]) {
    const unit = (row.unit ?? null) as Unit;
    const key = `${row.ingredient_id}|${unit ?? ''}`;
    const times = occurrences.get(row.recipe_id) ?? 1;
    const scale = persons / (recipeServings.get(row.recipe_id) ?? 1);

    let entry = map.get(key);
    if (!entry) {
      entry = { ingredient_id: row.ingredient_id, unit, total_quantity: 0, hasQuantity: false };
      map.set(key, entry);
    }
    if (row.quantity != null) {
      entry.total_quantity = (entry.total_quantity ?? 0) + row.quantity * scale * times;
      entry.hasQuantity = true;
    }
  }

  return [...map.values()].map((e) => ({
    ingredient_id: e.ingredient_id,
    unit: e.unit,
    total_quantity: e.hasQuantity ? roundQuantity(e.total_quantity ?? 0, e.unit) : null,
  }));
}

function roundQuantity(value: number, unit: Unit): number {
  // Whole units for countable / gram / millilitre amounts; two decimals else.
  if (unit === 'g' || unit === 'ml' || unit === 'Stück' || unit === null)
    return Math.round(value);
  return Math.round(value * 100) / 100;
}

// --- writes -----------------------------------------------------------------

/** Build and store the shopping list for a freshly confirmed plan. */
export async function createShoppingListForPlan(
  planId: string,
  persons: number,
  picks: GeneratedPick[],
): Promise<string> {
  const userId = await ensureSession();

  const { data: list, error } = await supabase
    .from('shopping_lists')
    .insert({ plan_id: planId, user_id: userId, status: 'open' })
    .select('id')
    .single();
  if (error) throw error;
  const listId = (list as { id: string }).id;

  const items = await aggregateIngredients(persons, picks);
  if (items.length > 0) {
    const rows = items.map((it) => ({
      list_id: listId,
      ingredient_id: it.ingredient_id,
      user_id: userId,
      total_quantity: it.total_quantity,
      unit: it.unit,
      checked: false,
    }));
    const { error: itemError } = await supabase
      .from('shopping_list_items')
      .insert(rows);
    if (itemError) throw itemError;
  }
  return listId;
}

export async function toggleShoppingItem(id: string, checked: boolean): Promise<void> {
  await ensureSession();
  const { error } = await supabase
    .from('shopping_list_items')
    .update({ checked })
    .eq('id', id);
  if (error) throw error;
}

// --- reads ------------------------------------------------------------------

export interface ShoppingItemView extends ShoppingListItem {
  ingredient: Pick<Ingredient, 'id' | 'name' | 'category'>;
}

export interface ShoppingListView {
  listId: string;
  planTitle: string;
  persons: number;
  /** Items grouped by ingredient category ("Sonstiges" when unset). */
  groups: { category: string; items: ShoppingItemView[] }[];
  totalCount: number;
  checkedCount: number;
}

/** The shopping list for the most recently created plan, grouped for display. */
export async function getLatestShoppingList(): Promise<ShoppingListView | null> {
  await ensureSession();

  const { data: plan, error: planError } = await supabase
    .from('meal_plans')
    .select('id,title,servings')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (planError) throw planError;
  if (!plan) return null;

  const { data: list, error: listError } = await supabase
    .from('shopping_lists')
    .select('id')
    .eq('plan_id', (plan as any).id)
    .maybeSingle();
  if (listError) throw listError;
  if (!list) return null;
  const listId = (list as { id: string }).id;

  const { data: items, error: itemError } = await supabase
    .from('shopping_list_items')
    .select('*, ingredient:ingredients(id,name,category)')
    .eq('list_id', listId);
  if (itemError) throw itemError;

  const rows = (items ?? []) as any as ShoppingItemView[];
  rows.sort((a, b) => a.ingredient.name.localeCompare(b.ingredient.name, 'de'));

  const byCategory = new Map<string, ShoppingItemView[]>();
  for (const row of rows) {
    const cat = row.ingredient.category?.trim() || 'Sonstiges';
    if (!byCategory.has(cat)) byCategory.set(cat, []);
    byCategory.get(cat)!.push(row);
  }
  const groups = [...byCategory.entries()]
    .sort((a, b) => a[0].localeCompare(b[0], 'de'))
    .map(([category, groupItems]) => ({ category, items: groupItems }));

  return {
    listId,
    planTitle: (plan as any).title,
    persons: (plan as any).servings,
    groups,
    totalCount: rows.length,
    checkedCount: rows.filter((r) => r.checked).length,
  };
}

// --- display helpers --------------------------------------------------------

/** Human-friendly amount, e.g. 1500 g -> "1,5 kg", 2 Stück -> "2 Stück". */
export function formatAmount(quantity: number | null, unit: Unit): string {
  if (quantity == null) return 'nach Bedarf';
  let value = quantity;
  let label: string = unit ?? '';
  if (unit === 'g' && value >= 1000) {
    value = value / 1000;
    label = 'kg';
  } else if (unit === 'ml' && value >= 1000) {
    value = value / 1000;
    label = 'l';
  }
  const rounded = Math.round(value * 100) / 100;
  const text = Number.isInteger(rounded)
    ? String(rounded)
    : rounded.toFixed(2).replace(/0+$/, '').replace('.', ',');
  return label ? `${text} ${label}` : text;
}

/** Plain-text export of the list (shopping-list fallback before REWE, Phase 6). */
export function shoppingListToText(view: ShoppingListView): string {
  const lines = [`Einkaufsliste — ${view.planTitle} (${view.persons} Personen)`, ''];
  for (const group of view.groups) {
    lines.push(`${group.category}:`);
    for (const item of group.items) {
      lines.push(`- ${item.ingredient.name} ${formatAmount(item.total_quantity, item.unit)}`.trimEnd());
    }
    lines.push('');
  }
  return lines.join('\n').trim();
}
