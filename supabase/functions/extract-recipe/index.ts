// Extracts a structured recipe from a PDF or image using the Google Gemini
// free tier. Stateless: no database access, returns a draft the app shows in
// its review screen before saving.
//
// Request  (POST, JSON):
//   { fileBase64: string, mimeType: string, sourceRef?: string }
//     mimeType: "application/pdf" | "image/jpeg" | "image/png" | "image/webp"
// Response (JSON):
//   { draft: RecipeDraft } | { error: string }
//
// Env: GEMINI_API_KEY   (set with `supabase secrets set`)
//      GEMINI_MODEL      (optional, default "gemini-2.5-flash")

import { corsHeaders, json } from '../_shared/cors.ts';

const MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-2.5-flash';
const API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';

const ALLOWED_UNITS = [
  'g', 'ml', 'Stück', 'EL', 'TL', 'Prise', 'Dose', 'Bund', 'Packung',
];

const RESPONSE_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    description: { type: 'string' },
    servings: { type: 'integer' },
    kcal_per_serving: { type: 'integer' },
    prep_minutes: { type: 'integer' },
    ingredients: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          raw_text: { type: 'string' },
          name: { type: 'string' },
          quantity: { type: 'number' },
          unit: { type: 'string', enum: [...ALLOWED_UNITS, ''] },
          note: { type: 'string' },
        },
        required: ['name', 'raw_text'],
      },
    },
    steps: { type: 'array', items: { type: 'string' } },
    tags: { type: 'array', items: { type: 'string' } },
  },
  required: ['title', 'servings', 'ingredients', 'steps'],
};

const PROMPT = `Du bekommst ein Rezept als PDF oder Bild. Extrahiere es als JSON.

Regeln:
- title: Name des Gerichts.
- servings: für wie viele Portionen das Originalrezept ausgelegt ist (Zahl). Wenn nicht angegeben: 2.
- kcal_per_serving: Kalorien pro Portion, nur wenn im Rezept genannt, sonst weglassen.
- prep_minutes: Gesamtzeit in Minuten, nur wenn genannt.
- ingredients: eine Zutat pro Eintrag.
  - raw_text: die Zutatenzeile wörtlich wie im Rezept.
  - name: die reine Zutat ohne Menge/Zubereitung (z. B. "Feta").
  - quantity: Menge als Zahl. Brüche und "1 1/2" in Dezimal umrechnen. kg -> g (mal 1000), l -> ml (mal 1000).
  - unit: genau einer von ${ALLOWED_UNITS.join(', ')} oder "" wenn keine Einheit.
  - note: Zusatz wie "gewürfelt", "fein gehackt", sonst weglassen.
- steps: Zubereitungsschritte, ein String pro Schritt, ohne Nummerierung.
- tags: kurze Schlagworte klein geschrieben, z. B. "bake and dump", "vegetarisch", "one pot". Nur wenn eindeutig ableitbar.

Antworte ausschließlich mit dem JSON.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);
  if (!API_KEY) return json({ error: 'GEMINI_API_KEY nicht gesetzt' }, 500);

  let payload: { fileBase64?: string; mimeType?: string; sourceRef?: string };
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Ungültiger JSON-Body' }, 400);
  }

  const { fileBase64, mimeType } = payload;
  if (!fileBase64 || !mimeType) {
    return json({ error: 'fileBase64 und mimeType erforderlich' }, 400);
  }
  // Base64 inflates ~33%; keep the whole request comfortably under Gemini's
  // ~20 MB inline limit.
  if (fileBase64.length > 14_000_000) {
    return json({ error: 'Datei zu groß (max ~10 MB). Bitte kürzen.' }, 413);
  }

  const geminiReq = {
    contents: [
      {
        role: 'user',
        parts: [
          { text: PROMPT },
          { inlineData: { mimeType, data: fileBase64 } },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      responseMimeType: 'application/json',
      responseSchema: RESPONSE_SCHEMA,
    },
  };

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

  let res: Response;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': API_KEY,
      },
      body: JSON.stringify(geminiReq),
    });
  } catch (e) {
    return json({ error: `Gemini nicht erreichbar: ${e}` }, 502);
  }

  const body = await res.json().catch(() => null);
  if (!res.ok) {
    const msg = body?.error?.message ?? `HTTP ${res.status}`;
    const status = res.status === 429 ? 429 : 502;
    return json(
      { error: `Gemini-Fehler: ${msg}`, hint: status === 429 ? 'Tageslimit erreicht — später erneut oder Groq-Fallback.' : undefined },
      status,
    );
  }

  const text: string | undefined =
    body?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) return json({ error: 'Leere Antwort von Gemini' }, 502);

  let draft: unknown;
  try {
    draft = JSON.parse(text);
  } catch {
    return json({ error: 'Gemini-Antwort war kein gültiges JSON' }, 502);
  }

  return json({ draft });
});
