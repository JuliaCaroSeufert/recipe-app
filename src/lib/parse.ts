import type { Unit } from './types';

export interface ParsedIngredientLine {
  quantity: number | null;
  unit: Unit;
  name: string;
  note: string | null;
  raw: string;
}

const UNIT_MAP: Record<string, Exclude<Unit, null>> = {
  g: 'g',
  gr: 'g',
  gramm: 'g',
  kg: 'g', // normalised below
  kilogramm: 'g',
  ml: 'ml',
  milliliter: 'ml',
  l: 'ml', // normalised below
  liter: 'ml',
  el: 'EL',
  esslöffel: 'EL',
  tl: 'TL',
  teelöffel: 'TL',
  stk: 'Stück',
  stück: 'Stück',
  prise: 'Prise',
  prisen: 'Prise',
  dose: 'Dose',
  dosen: 'Dose',
  bund: 'Bund',
  packung: 'Packung',
  pck: 'Packung',
  pkg: 'Packung',
  päckchen: 'Packung',
};

/** "1,5" / "1 1/2" / "½" -> number */
function parseQuantity(raw: string): number | null {
  const s = raw.trim().replace(',', '.');
  const vulgar: Record<string, number> = {
    '½': 0.5, '¼': 0.25, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3,
  };
  if (vulgar[s] != null) return vulgar[s];
  const mixed = s.match(/^(\d+)\s+(\d+)\/(\d+)$/);
  if (mixed) return Number(mixed[1]) + Number(mixed[2]) / Number(mixed[3]);
  const frac = s.match(/^(\d+)\/(\d+)$/);
  if (frac) return Number(frac[1]) / Number(frac[2]);
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

/**
 * Best-effort parse of one ingredient line such as
 *   "200 g Feta, gewürfelt"  ->  { quantity: 200, unit: 'g', name: 'Feta', note: 'gewürfelt' }
 *   "1 Dose Kichererbsen"    ->  { quantity: 1, unit: 'Dose', name: 'Kichererbsen' }
 *   "Salz"                   ->  { quantity: null, unit: null, name: 'Salz' }
 * Not exhaustive — the review screen lets the user fix anything.
 */
export function parseIngredientLine(line: string): ParsedIngredientLine {
  const raw = line.trim();
  let rest = raw;
  let note: string | null = null;

  const commaIdx = rest.indexOf(',');
  if (commaIdx !== -1) {
    note = rest.slice(commaIdx + 1).trim() || null;
    rest = rest.slice(0, commaIdx).trim();
  }

  const qtyMatch = rest.match(/^(\d+[.,]?\d*\s*\d*\/?\d*|[½¼¾⅓⅔])\s*(.*)$/);
  let quantity: number | null = null;
  let unit: Unit = null;

  if (qtyMatch) {
    quantity = parseQuantity(qtyMatch[1]);
    rest = qtyMatch[2].trim();

    const firstWord = rest.split(/\s+/)[0]?.toLowerCase().replace(/\.$/, '');
    if (firstWord && UNIT_MAP[firstWord]) {
      unit = UNIT_MAP[firstWord];
      rest = rest.slice(rest.split(/\s+/)[0].length).trim();
      if (firstWord === 'kg' || firstWord === 'kilogramm') {
        if (quantity != null) quantity *= 1000;
      }
      if (firstWord === 'l' || firstWord === 'liter') {
        if (quantity != null) quantity *= 1000;
      }
    }
  }

  return { quantity, unit, name: rest.trim(), note, raw };
}

/** Split a pasted ingredient block into non-empty trimmed lines. */
export function splitIngredientBlock(block: string): string[] {
  return block
    .split(/\r?\n/)
    .map((l) => l.replace(/^[-*•\d.)\s]+/, '').trim())
    .filter(Boolean);
}
