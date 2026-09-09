import type { RecipeDraft } from './types';

// One-shot hand-off between the import flow and the recipe review form.
// The form calls takeDraft() once on mount; it is cleared immediately so a
// later manual "+ Rezept" does not reuse it.
let pending: RecipeDraft | null = null;

export function setDraft(draft: RecipeDraft): void {
  pending = draft;
}

export function takeDraft(): RecipeDraft | null {
  const d = pending;
  pending = null;
  return d;
}
