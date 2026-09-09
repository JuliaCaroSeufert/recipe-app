import { ensureSession, supabase } from './supabase';
import type {
  Ingredient,
  Recipe,
  RecipeWithDetail,
  SourceType,
  Unit,
} from './types';

export interface RecipeInput {
  title: string;
  description?: string | null;
  image_url?: string | null;
  source_type?: SourceType;
  source_ref?: string | null;
  servings: number;
  kcal_per_serving?: number | null;
  prep_minutes?: number | null;
  steps: string[];
  ingredients: RecipeIngredientInput[];
  tags: string[];
}

export interface RecipeIngredientInput {
  name: string;
  quantity: number | null;
  unit: Unit;
  note?: string | null;
  raw_text?: string | null;
}

// --- reads ---------------------------------------------------------------

export async function listRecipes(): Promise<Recipe[]> {
  await ensureSession();
  const { data, error } = await supabase
    .from('recipes')
    .select('*')
    .order('created_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as Recipe[];
}

export async function getRecipe(id: string): Promise<RecipeWithDetail | null> {
  await ensureSession();
  const { data, error } = await supabase
    .from('recipes')
    .select(
      `*,
       ingredients:recipe_ingredients(
         *, ingredient:ingredients(*)
       ),
       recipe_tags(tag:tags(*))`,
    )
    .eq('id', id)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;

  const row = data as any;
  return {
    ...(row as Recipe),
    ingredients: (row.ingredients ?? []).sort(
      (a: any, b: any) => a.sort - b.sort,
    ),
    tags: (row.recipe_tags ?? []).map((rt: any) => rt.tag).filter(Boolean),
  };
}

// --- ingredient / tag catalog -----------------------------------------------

async function getOrCreateIngredient(
  userId: string,
  name: string,
): Promise<Ingredient> {
  const clean = name.trim();
  const { data: existing } = await supabase
    .from('ingredients')
    .select('*')
    .eq('user_id', userId)
    .ilike('name', clean)
    .maybeSingle();
  if (existing) return existing as Ingredient;

  const { data, error } = await supabase
    .from('ingredients')
    .insert({ user_id: userId, name: clean })
    .select('*')
    .single();
  if (error) throw error;
  return data as Ingredient;
}

async function getOrCreateTag(userId: string, name: string): Promise<string> {
  const clean = name.trim().toLowerCase();
  const { data: existing } = await supabase
    .from('tags')
    .select('id')
    .eq('user_id', userId)
    .eq('name', clean)
    .maybeSingle();
  if (existing) return (existing as { id: string }).id;

  const { data, error } = await supabase
    .from('tags')
    .insert({ user_id: userId, name: clean })
    .select('id')
    .single();
  if (error) throw error;
  return (data as { id: string }).id;
}

// --- writes ---------------------------------------------------------------

export async function createRecipe(input: RecipeInput): Promise<string> {
  const userId = await ensureSession();

  const { data: recipe, error } = await supabase
    .from('recipes')
    .insert({
      user_id: userId,
      title: input.title.trim(),
      description: input.description ?? null,
      image_url: input.image_url ?? null,
      source_type: input.source_type ?? 'manual',
      source_ref: input.source_ref ?? null,
      servings: input.servings,
      kcal_per_serving: input.kcal_per_serving ?? null,
      prep_minutes: input.prep_minutes ?? null,
      steps: input.steps,
    })
    .select('id')
    .single();
  if (error) throw error;
  const recipeId = (recipe as { id: string }).id;

  await replaceIngredients(userId, recipeId, input.ingredients);
  await replaceTags(userId, recipeId, input.tags);
  return recipeId;
}

export async function updateRecipe(
  id: string,
  input: RecipeInput,
): Promise<void> {
  const userId = await ensureSession();

  const { error } = await supabase
    .from('recipes')
    .update({
      title: input.title.trim(),
      description: input.description ?? null,
      image_url: input.image_url ?? null,
      servings: input.servings,
      kcal_per_serving: input.kcal_per_serving ?? null,
      prep_minutes: input.prep_minutes ?? null,
      steps: input.steps,
    })
    .eq('id', id);
  if (error) throw error;

  await replaceIngredients(userId, id, input.ingredients);
  await replaceTags(userId, id, input.tags);
}

export async function deleteRecipe(id: string): Promise<void> {
  await ensureSession();
  const { error } = await supabase.from('recipes').delete().eq('id', id);
  if (error) throw error;
}

async function replaceIngredients(
  userId: string,
  recipeId: string,
  items: RecipeIngredientInput[],
): Promise<void> {
  await supabase.from('recipe_ingredients').delete().eq('recipe_id', recipeId);
  if (items.length === 0) return;

  const rows = [];
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    if (!it.name.trim()) continue;
    const ing = await getOrCreateIngredient(userId, it.name);
    rows.push({
      recipe_id: recipeId,
      ingredient_id: ing.id,
      user_id: userId,
      raw_text: it.raw_text ?? null,
      quantity: it.quantity,
      unit: it.unit,
      note: it.note ?? null,
      sort: i,
    });
  }
  if (rows.length === 0) return;
  const { error } = await supabase.from('recipe_ingredients').insert(rows);
  if (error) throw error;
}

async function replaceTags(
  userId: string,
  recipeId: string,
  tags: string[],
): Promise<void> {
  await supabase.from('recipe_tags').delete().eq('recipe_id', recipeId);
  const unique = [...new Set(tags.map((t) => t.trim()).filter(Boolean))];
  if (unique.length === 0) return;

  const rows = [];
  for (const name of unique) {
    const tagId = await getOrCreateTag(userId, name);
    rows.push({ recipe_id: recipeId, tag_id: tagId, user_id: userId });
  }
  const { error } = await supabase.from('recipe_tags').insert(rows);
  if (error) throw error;
}
