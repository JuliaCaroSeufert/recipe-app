// Hand-written types mirroring supabase/migrations/0001_init.sql.
// Regenerate with `supabase gen types typescript` later if the schema grows.

export type SourceType = 'manual' | 'pdf' | 'instagram';
export type PlanStatus = 'draft' | 'confirmed';
export type ShoppingStatus = 'open' | 'ordered';

export type Unit =
  | 'g'
  | 'ml'
  | 'Stück'
  | 'EL'
  | 'TL'
  | 'Prise'
  | 'Dose'
  | 'Bund'
  | 'Packung'
  | null;

export interface Recipe {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  image_url: string | null;
  source_type: SourceType;
  source_ref: string | null;
  servings: number;
  kcal_per_serving: number | null;
  prep_minutes: number | null;
  steps: string[];
  created_at: string;
  updated_at: string;
}

export interface Tag {
  id: string;
  user_id: string;
  name: string;
  kind: 'method' | 'diet' | 'cuisine' | 'custom' | null;
}

export interface Ingredient {
  id: string;
  user_id: string;
  name: string;
  category: string | null;
  density_g_per_ml: number | null;
  rewe_product_id: string | null;
}

export interface RecipeIngredient {
  id: string;
  recipe_id: string;
  ingredient_id: string;
  user_id: string;
  raw_text: string | null;
  quantity: number | null;
  unit: Unit;
  note: string | null;
  sort: number;
}

/** Recipe with its joined ingredients and tags, as used by detail/edit screens. */
export interface RecipeWithDetail extends Recipe {
  ingredients: (RecipeIngredient & { ingredient: Ingredient })[];
  tags: Tag[];
}

export interface MealPlan {
  id: string;
  user_id: string;
  title: string;
  start_date: string | null;
  days: number;
  meals_per_day: number;
  servings: number;
  status: PlanStatus;
  filters: PlanFilters;
  created_at: string;
}

export interface PlanFilters {
  days?: number;
  mealsPerDay?: number;
  maxKcalPerServing?: number;
  /** e.g. [{ tag: "bake and dump", min: 3 }] */
  tagRules?: { tag: string; min?: number; max?: number }[];
  includeTags?: string[];
  excludeTags?: string[];
}

export interface MealPlanEntry {
  id: string;
  plan_id: string;
  recipe_id: string;
  user_id: string;
  day_index: number;
  slot_index: number;
  servings_override: number | null;
}

export interface ShoppingList {
  id: string;
  plan_id: string;
  user_id: string;
  status: ShoppingStatus;
  created_at: string;
}

export interface ShoppingListItem {
  id: string;
  list_id: string;
  ingredient_id: string;
  user_id: string;
  total_quantity: number | null;
  unit: Unit;
  checked: boolean;
  rewe_product_id: string | null;
  rewe_qty: number | null;
}

// --- Minimal Database shape for the typed supabase client ------------------
type Row<T> = T;
type Insert<T> = Partial<T>;
type Update<T> = Partial<T>;

interface TableDef<T> {
  Row: Row<T>;
  Insert: Insert<T>;
  Update: Update<T>;
  Relationships: [];
}

export interface Database {
  public: {
    Tables: {
      recipes: TableDef<Recipe>;
      tags: TableDef<Tag>;
      recipe_tags: TableDef<{ recipe_id: string; tag_id: string; user_id: string }>;
      ingredients: TableDef<Ingredient>;
      recipe_ingredients: TableDef<RecipeIngredient>;
      meal_plans: TableDef<MealPlan>;
      meal_plan_entries: TableDef<MealPlanEntry>;
      shopping_lists: TableDef<ShoppingList>;
      shopping_list_items: TableDef<ShoppingListItem>;
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
