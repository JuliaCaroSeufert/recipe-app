import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

/** True when both env vars are present; screens show a setup hint otherwise. */
export const isSupabaseConfigured = Boolean(url && anonKey);

export const supabase = createClient(
  url ?? 'http://localhost',
  anonKey ?? 'public-anon-key',
  {
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  },
);

/**
 * Ensures there is a signed-in user. For a single-user personal app an
 * anonymous session is enough — enable "Anonymous sign-ins" in the Supabase
 * dashboard (Authentication -> Providers). Returns the user id.
 */
export async function ensureSession(): Promise<string> {
  const { data } = await supabase.auth.getSession();
  if (data.session?.user) return data.session.user.id;

  const { data: signIn, error } = await supabase.auth.signInAnonymously();
  if (error) throw error;
  if (!signIn.user) throw new Error('Anonyme Anmeldung fehlgeschlagen');
  return signIn.user.id;
}
