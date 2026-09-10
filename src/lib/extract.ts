import * as DocumentPicker from 'expo-document-picker';
import { File } from 'expo-file-system';
import * as ImagePicker from 'expo-image-picker';

import { ensureSession, supabase } from './supabase';
import type { RecipeDraft, SourceType } from './types';

const MAX_BYTES = 10 * 1024 * 1024; // 10 MB

export class ExtractCancelled extends Error {}

interface ExtractBody {
  fileBase64?: string;
  mimeType?: string;
  text?: string;
  sourceRef?: string;
}

/** Low-level call into the extract-recipe edge function. Returns the raw draft. */
async function invokeExtract(body: ExtractBody): Promise<RecipeDraft> {
  await ensureSession();

  const { data, error } = await supabase.functions.invoke('extract-recipe', {
    body,
  });

  if (error) {
    // Edge function returns a JSON { error } body on failure.
    const detail =
      (error as { context?: { error?: string } })?.context?.error ??
      error.message;
    throw new Error(detail || 'Extraktion fehlgeschlagen');
  }
  if (data?.error) throw new Error(data.error as string);
  if (!data?.draft) throw new Error('Keine Rezeptdaten erkannt');
  return data.draft as RecipeDraft;
}

function withSource(
  draft: RecipeDraft,
  sourceType: SourceType,
  sourceRef: string | null,
): RecipeDraft {
  return { ...draft, source_type: sourceType, source_ref: sourceRef };
}

/**
 * Opens the file picker for a PDF, sends it to the extract-recipe edge
 * function and returns a draft. Throws ExtractCancelled if the user backs out.
 */
export async function pickAndExtractPdf(): Promise<RecipeDraft> {
  const picked = await DocumentPicker.getDocumentAsync({
    type: 'application/pdf',
    copyToCacheDirectory: true,
    multiple: false,
  });
  if (picked.canceled || !picked.assets?.[0]) throw new ExtractCancelled();

  const asset = picked.assets[0];
  if (asset.size != null && asset.size > MAX_BYTES) {
    throw new Error('PDF ist größer als 10 MB. Bitte kürzen oder aufteilen.');
  }

  const base64 = await new File(asset.uri).base64();
  const draft = await invokeExtract({
    fileBase64: base64,
    mimeType: 'application/pdf',
    sourceRef: asset.name ?? 'PDF',
  });
  return withSource(draft, 'pdf', asset.name ?? null);
}

/**
 * Extract a recipe from a pasted Instagram caption (or any recipe text).
 * `postUrl` is kept as the recipe's source reference.
 */
export async function extractFromCaption(
  caption: string,
  postUrl?: string,
): Promise<RecipeDraft> {
  const text = caption.trim();
  if (!text) throw new Error('Bitte den Rezepttext einfügen.');
  const draft = await invokeExtract({ text, sourceRef: postUrl?.trim() || undefined });
  return withSource(draft, 'instagram', postUrl?.trim() || null);
}

/**
 * Pick a screenshot from the gallery (e.g. of an Instagram recipe) and extract
 * it. Throws ExtractCancelled if the user backs out.
 */
export async function pickAndExtractScreenshot(
  postUrl?: string,
): Promise<RecipeDraft> {
  const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!perm.granted) {
    throw new Error('Zugriff auf die Galerie wurde nicht erlaubt.');
  }

  const picked = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images'],
    base64: true,
    quality: 0.8,
  });
  if (picked.canceled || !picked.assets?.[0]) throw new ExtractCancelled();

  const asset = picked.assets[0];
  if (!asset.base64) throw new Error('Bild konnte nicht gelesen werden.');
  if (asset.base64.length > 14_000_000) {
    throw new Error('Screenshot zu groß. Bitte kleiner wählen.');
  }

  const draft = await invokeExtract({
    fileBase64: asset.base64,
    mimeType: asset.mimeType ?? 'image/jpeg',
    sourceRef: postUrl?.trim() || undefined,
  });
  return withSource(draft, 'instagram', postUrl?.trim() || null);
}
