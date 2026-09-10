import { useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useState } from 'react';
import { Alert, Pressable, Share, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { Button, Card, Empty, Screen } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { isSupabaseConfigured } from '@/lib/supabase';
import {
  formatAmount,
  getLatestShoppingList,
  shoppingListToText,
  toggleShoppingItem,
  type ShoppingListView,
} from '@/lib/shopping';

export default function ShoppingScreen() {
  const theme = useTheme();
  const router = useRouter();
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

  async function toggle(id: string, checked: boolean) {
    // optimistic
    setView((v) =>
      v
        ? {
            ...v,
            checkedCount: v.checkedCount + (checked ? 1 : -1),
            groups: v.groups.map((g) => ({
              ...g,
              items: g.items.map((it) => (it.id === id ? { ...it, checked } : it)),
            })),
          }
        : v,
    );
    try {
      await toggleShoppingItem(id, checked);
    } catch {
      load(); // revert to server state on failure
    }
  }

  async function share() {
    if (!view) return;
    try {
      await Share.share({ message: shoppingListToText(view) });
    } catch (e) {
      Alert.alert('Teilen fehlgeschlagen', e instanceof Error ? e.message : String(e));
    }
  }

  if (loading) {
    return (
      <Screen>
        <ThemedText>Lädt…</ThemedText>
      </Screen>
    );
  }
  if (error) {
    return (
      <Screen>
        <Empty title="Kann Einkaufsliste nicht laden" hint={error} />
      </Screen>
    );
  }
  if (!view) {
    return (
      <Screen>
        <Empty
          title="Noch keine Einkaufsliste"
          hint="Erstelle im Tab „Wochenplan“ einen Plan und bestätige ihn — daraus entsteht die Einkaufsliste."
        />
      </Screen>
    );
  }

  return (
    <Screen>
      <ThemedText type="subtitle">Einkaufsliste</ThemedText>
      <ThemedText type="small" themeColor="textSecondary">
        {view.planTitle} · {view.persons} Personen · {view.checkedCount}/
        {view.totalCount} erledigt
      </ThemedText>

      {view.groups.map((group) => (
        <Card key={group.category}>
          <ThemedText type="smallBold">{group.category}</ThemedText>
          {group.items.map((item) => (
            <Pressable
              key={item.id}
              onPress={() => toggle(item.id, !item.checked)}
              style={styles.itemRow}>
              <View
                style={[
                  styles.checkbox,
                  {
                    borderColor: theme.textSecondary,
                    backgroundColor: item.checked ? '#3c87f7' : 'transparent',
                  },
                ]}>
                {item.checked ? (
                  <ThemedText style={styles.checkMark}>✓</ThemedText>
                ) : null}
              </View>
              <ThemedText
                type="small"
                style={[styles.itemName, item.checked && styles.itemChecked]}
                themeColor={item.checked ? 'textSecondary' : 'text'}>
                {item.ingredient.name}
              </ThemedText>
              <ThemedText type="small" themeColor="textSecondary">
                {formatAmount(item.total_quantity, item.unit)}
              </ThemedText>
            </Pressable>
          ))}
        </Card>
      ))}

      <Button title="Bei REWE bestellen" onPress={() => router.push('/rewe')} />
      <Button title="Als Text teilen" variant="secondary" onPress={share} />
      <View style={{ height: Spacing.five }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.two,
    paddingVertical: Spacing.one,
  },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: 6,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkMark: { color: '#fff', fontSize: 14, lineHeight: 16 },
  itemName: { flex: 1 },
  itemChecked: { textDecorationLine: 'line-through' },
});
