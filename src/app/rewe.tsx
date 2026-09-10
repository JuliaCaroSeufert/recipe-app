import { Stack, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { Alert, Pressable, Share, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { Button, Card, Empty, Screen } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import {
  formatAmount,
  getLatestShoppingList,
  shoppingListToText,
  type ShoppingListView,
} from '@/lib/shopping';
import { openReweForList, openReweSearch, setListStatus } from '@/lib/rewe';
import { isSupabaseConfigured } from '@/lib/supabase';

export default function ReweScreen() {
  const theme = useTheme();
  const [view, setView] = useState<ShoppingListView | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!isSupabaseConfigured) {
      setLoading(false);
      setError('Supabase nicht konfiguriert — siehe README (.env).');
      return;
    }
    try {
      setError(null);
      setView(await getLatestShoppingList());
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Fehler beim Laden');
    } finally {
      setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  async function open(term: string) {
    try {
      await openReweSearch(term);
    } catch (e) {
      Alert.alert('REWE öffnen fehlgeschlagen', e instanceof Error ? e.message : String(e));
    }
  }

  async function openAll() {
    if (!view) return;
    try {
      await openReweForList(view);
    } catch (e) {
      Alert.alert('REWE öffnen fehlgeschlagen', e instanceof Error ? e.message : String(e));
    }
  }

  async function toggleOrdered() {
    if (!view) return;
    const next = view.status === 'ordered' ? 'open' : 'ordered';
    setView({ ...view, status: next });
    try {
      await setListStatus(view.listId, next);
    } catch {
      load();
    }
  }

  async function shareText() {
    if (!view) return;
    try {
      await Share.share({ message: shoppingListToText(view) });
    } catch {
      /* user dismissed */
    }
  }

  if (loading) {
    return (
      <Screen>
        <Stack.Screen options={{ title: 'Bei REWE bestellen' }} />
        <ThemedText>Lädt…</ThemedText>
      </Screen>
    );
  }
  if (error || !view) {
    return (
      <Screen>
        <Stack.Screen options={{ title: 'Bei REWE bestellen' }} />
        <Empty
          title="Keine Einkaufsliste"
          hint={error ?? 'Bestätige zuerst einen Wochenplan, dann kannst du die Zutaten bei REWE bestellen.'}
        />
      </Screen>
    );
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: 'Bei REWE bestellen' }} />

      <Card>
        <ThemedText type="smallBold">So funktioniert&apos;s</ThemedText>
        <ThemedText type="small" themeColor="textSecondary">
          REWE bietet keine offene Bestell-Schnittstelle. Die App öffnet für jede
          Zutat direkt die REWE-Produktsuche (in der REWE-App, falls installiert,
          sonst im Browser). Dort wählst du dein Produkt, legst es in den
          Warenkorb und schließt die Bestellung wie gewohnt bei REWE ab —
          Lieferadresse und Bezahlung bleiben komplett bei REWE.
        </ThemedText>
      </Card>

      <Button title="Ganze Liste bei REWE öffnen" onPress={openAll} />

      {view.groups.map((group) => (
        <Card key={group.category}>
          <ThemedText type="smallBold">{group.category}</ThemedText>
          {group.items.map((item) => (
            <View key={item.id} style={styles.row}>
              <View style={styles.main}>
                <ThemedText
                  type="small"
                  themeColor={item.checked ? 'textSecondary' : 'text'}
                  style={item.checked ? styles.done : undefined}>
                  {item.ingredient.name}
                </ThemedText>
                <ThemedText type="small" themeColor="textSecondary">
                  {formatAmount(item.total_quantity, item.unit)}
                </ThemedText>
              </View>
              <Pressable
                onPress={() => open(item.ingredient.name)}
                style={[styles.searchBtn, { backgroundColor: theme.backgroundSelected }]}>
                <ThemedText type="small">Bei REWE suchen</ThemedText>
              </Pressable>
            </View>
          ))}
        </Card>
      ))}

      <Button
        title={view.status === 'ordered' ? '✓ Als bestellt markiert' : 'Als bestellt markieren'}
        variant={view.status === 'ordered' ? 'secondary' : 'primary'}
        onPress={toggleOrdered}
      />
      <Button title="Liste als Text teilen" variant="ghost" onPress={shareText} />
      <View style={{ height: Spacing.five }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.two,
    paddingVertical: Spacing.one,
  },
  main: { flex: 1, gap: 2 },
  done: { textDecorationLine: 'line-through' },
  searchBtn: {
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    borderRadius: Spacing.two,
  },
});
