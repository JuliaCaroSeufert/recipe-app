import * as DocumentPicker from 'expo-document-picker';
import { File } from 'expo-file-system';

import { ensureSession, supabase } from './supabase';
import type { RecipeDraft } from './types';

const MAX_BYTES = 10 * 1024 * 1024; // 10 MB

export class ExtractCancelled extends Error {}

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
  return extract(base64, 'application/pdf', asset.name ?? 'PDF');
}

/** Shared call into the edge function (also used by the Instagram flow later). */
export async function extract(
  fileBase64: string,
  mimeType: string,
  sourceRef: string,
): Promise<RecipeDraft> {
  await ensureSession();

  const { data, error } = await supabase.functions.invoke('extract-recipe', {
    body: { fileBase64, mimeType, sourceRef },
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

  return {
    ...(data.draft as RecipeDraft),
    source_type: mimeType === 'application/pdf' ? 'pdf' : 'instagram',
    source_ref: sourceRef,
  };
}
