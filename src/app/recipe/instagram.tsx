import { Stack, useRouter } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Alert, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { Button, Field, Screen } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { setDraft } from '@/lib/draft';
import {
  ExtractCancelled,
  extractFromCaption,
  pickAndExtractScreenshot,
} from '@/lib/extract';

export default function InstagramImportScreen() {
  const router = useRouter();
  const theme = useTheme();
  const [url, setUrl] = useState('');
  const [caption, setCaption] = useState('');
  const [busy, setBusy] = useState<null | 'text' | 'image'>(null);

  async function run(kind: 'text' | 'image') {
    setBusy(kind);
    try {
      const draft =
        kind === 'text'
          ? await extractFromCaption(caption, url)
          : await pickAndExtractScreenshot(url);
      setDraft(draft);
      router.replace('/recipe/new');
    } catch (e) {
      if (e instanceof ExtractCancelled) return;
      Alert.alert('Import fehlgeschlagen', e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(null);
    }
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: 'Instagram importieren' }} />

      <ThemedText type="small" themeColor="textSecondary">
        Öffne den Instagram-Beitrag, kopiere den Rezepttext aus der
        Bildunterschrift und füge ihn hier ein — oder importiere einen
        Screenshot des Rezepts. Der Text wird automatisch in Zutaten und
        Schritte zerlegt; danach kannst du alles prüfen.
      </ThemedText>

      <Field
        label="Beitrags-Link (optional)"
        value={url}
        onChangeText={setUrl}
        placeholder="https://www.instagram.com/p/…"
        autoCapitalize="none"
        keyboardType="url"
      />

      <Field
        label="Rezepttext aus der Bildunterschrift"
        value={caption}
        onChangeText={setCaption}
        placeholder="Hier den kopierten Text einfügen…"
        multiline
        style={styles.multiline}
        autoCapitalize="none"
      />

      <Button
        title="Aus Text lesen"
        onPress={() => run('text')}
        loading={busy === 'text'}
        disabled={busy !== null || !caption.trim()}
      />
      <Button
        title="Screenshot importieren"
        variant="secondary"
        onPress={() => run('image')}
        loading={busy === 'image'}
        disabled={busy !== null}
      />

      {busy && (
        <View style={[styles.overlay, { backgroundColor: theme.background }]}>
          <ActivityIndicator size="large" />
          <ThemedText type="small" themeColor="textSecondary">
            Rezept wird gelesen…
          </ThemedText>
        </View>
      )}
      <View style={{ height: Spacing.five }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  multiline: { minHeight: 160, textAlignVertical: 'top', paddingTop: Spacing.two },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.two,
    opacity: 0.96,
  },
});
