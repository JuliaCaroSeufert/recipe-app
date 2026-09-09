import { Link, useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, RefreshControl, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { Button, Empty, Screen } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { listRecipes } from '@/lib/recipes';
import { isSupabaseConfigured } from '@/lib/supabase';
import type { Recipe } from '@/lib/types';

export default function RecipesScreen() {
  const theme = useTheme();
  const router = useRouter();
  const [recipes, setRecipes] = useState<Recipe[]>([]);
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
      setRecipes(await listRecipes());
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

  if (error) {
    return (
      <Screen>
        <Empty title="Kann Rezepte nicht laden" hint={error} />
      </Screen>
    );
  }

  return (
    <Screen scroll={false}>
      <FlatList
        data={recipes}
        keyExtractor={(r) => r.id}
        contentContainerStyle={styles.list}
        refreshControl={
          <RefreshControl refreshing={loading} onRefresh={load} />
        }
        ListEmptyComponent={
          loading ? null : (
            <Empty
              title="Noch keine Rezepte"
              hint="Tippe unten auf „Rezept hinzufügen“."
            />
          )
        }
        renderItem={({ item }) => (
          <Link href={`/recipe/${item.id}`} asChild>
            <Pressable
              style={[
                styles.row,
                { backgroundColor: theme.backgroundElement },
              ]}>
              <View style={styles.rowMain}>
                <ThemedText type="smallBold">{item.title}</ThemedText>
                <ThemedText type="small" themeColor="textSecondary">
                  {item.servings} Portionen
                  {item.kcal_per_serving
                    ? ` · ${item.kcal_per_serving} kcal`
                    : ''}
                  {item.source_type !== 'manual'
                    ? ` · ${item.source_type}`
                    : ''}
                </ThemedText>
              </View>
              <ThemedText themeColor="textSecondary">›</ThemedText>
            </Pressable>
          </Link>
        )}
      />
      <View style={styles.footer}>
        <Button
          title="+ Rezept hinzufügen"
          onPress={() => router.push('/recipe/new')}
        />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  list: { padding: Spacing.three, gap: Spacing.two, flexGrow: 1 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: Spacing.three,
    padding: Spacing.three,
    gap: Spacing.two,
  },
  rowMain: { flex: 1, gap: 2 },
  footer: { padding: Spacing.three },
});
