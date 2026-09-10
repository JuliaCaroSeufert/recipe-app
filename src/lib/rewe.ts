// Phase 6 — REWE handoff.
//
// REWE has no public ordering API, and the endpoints behind shop.rewe.de are
// login-/cookie-/bot-protected, so a headless "fill my cart and check out" flow
// cannot be built reliably (and would breach REWE's terms). Instead we hand the
// shopping list over to REWE the robust way: a universal link that opens the
// REWE app (or shop.rewe.de in the browser) with the product search pre-filled,
// per ingredient and for the whole list. The user picks their market and
// confirms the cart inside REWE, where the payment/session already lives.

import * as Linking from 'expo-linking';

import { ensureSession, supabase } from './supabase';
import type { ShoppingStatus } from './types';
import { type ShoppingListView } from './shopping';

const REWE_SHOP = 'https://shop.rewe.de';

/** Universal link to REWE's product search for one term (opens app or web). */
export function reweSearchUrl(term: string): string {
  return `${REWE_SHOP}/productList?search=${encodeURIComponent(term.trim())}`;
}

/** Open REWE's product search for a single ingredient. */
export async function openReweSearch(term: string): Promise<void> {
  await Linking.openURL(reweSearchUrl(term));
}

/**
 * Open REWE for the whole list. There is no public "add all to cart" URL, so we
 * open the search for the first still-unchecked item; the caller walks the user
 * through the rest item by item.
 */
export async function openReweForList(view: ShoppingListView): Promise<void> {
  const first =
    view.groups.flatMap((g) => g.items).find((it) => !it.checked) ??
    view.groups.flatMap((g) => g.items)[0];
  if (!first) {
    await Linking.openURL(REWE_SHOP);
    return;
  }
  await openReweSearch(first.ingredient.name);
}

/** Mark the shopping list ordered (or back to open). */
export async function setListStatus(
  listId: string,
  status: ShoppingStatus,
): Promise<void> {
  await ensureSession();
  const { error } = await supabase
    .from('shopping_lists')
    .update({ status })
    .eq('id', listId);
  if (error) throw error;
}
