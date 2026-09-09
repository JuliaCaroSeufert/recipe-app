import { Image } from 'expo-image';
import { Stack, useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { useCallback, useState } from 'react';
import { Alert, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { Button, Card, Screen } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { deleteRecipe, getRecipe } from '@/lib/recipes';
import type { RecipeWithDetail } from '@/lib/types';

export default function RecipeDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const theme = useTheme();
  const [recipe, setRecipe] = useState<RecipeWithDetail | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      setRecipe(await getRecipe(id));
    } finally {
      setLoading(false);
    }
  }, [id]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  function confirmDelete() {
    Alert.alert('Rezept löschen?', 'Das kann nicht rückgängig gemacht werden.', [
      { text: 'Abbrechen', style: 'cancel' },
      {
        text: 'Löschen',
        style: 'destructive',
        onPress: async () => {
          await deleteRecipe(id);
          router.back();
        },
      },
    ]);
  }

  if (loading) {
    return (
      <Screen>
        <ThemedText>Lädt…</ThemedText>
      </Screen>
    );
  }
  if (!recipe) {
    return (
      <Screen>
        <ThemedText>Rezept nicht gefunden.</ThemedText>
      </Screen>
    );
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: recipe.title }} />

      {recipe.image_url ? (
        <Image
          source={{ uri: recipe.image_url }}
          style={styles.image}
          contentFit="cover"
        />
      ) : null}

      <ThemedText type="subtitle">{recipe.title}</ThemedText>
      <ThemedText type="small" themeColor="textSecondary">
        {recipe.servings} Portionen
        {recipe.kcal_per_serving ? ` · ${recipe.kcal_per_serving} kcal/Portion` : ''}
        {recipe.prep_minutes ? ` · ${recipe.prep_minutes} Min.` : ''}
      </ThemedText>

      {recipe.tags.length > 0 && (
        <View style={styles.tags}>
          {recipe.tags.map((t) => (
            <View
              key={t.id}
              style={[styles.tag, { backgroundColor: theme.backgroundSelected }]}>
              <ThemedText type="small">{t.name}</ThemedText>
            </View>
          ))}
        </View>
      )}

      {recipe.description ? (
        <ThemedText>{recipe.description}</ThemedText>
      ) : null}

      <Card>
        <ThemedText type="smallBold">Zutaten</ThemedText>
        {recipe.ingredients.map((ri) => (
          <ThemedText key={ri.id} type="small">
            • {ri.quantity ?? ''} {ri.unit ?? ''} {ri.ingredient.name}
            {ri.note ? `, ${ri.note}` : ''}
          </ThemedText>
        ))}
        {recipe.ingredients.length === 0 && (
          <ThemedText type="small" themeColor="textSecondary">
            keine
          </ThemedText>
        )}
      </Card>

      <Card>
        <ThemedText type="smallBold">Zubereitung</ThemedText>
        {recipe.steps.map((s, i) => (
          <ThemedText key={i} type="small">
            {i + 1}. {s}
          </ThemedText>
        ))}
        {recipe.steps.length === 0 && (
          <ThemedText type="small" themeColor="textSecondary">
            keine Schritte
          </ThemedText>
        )}
      </Card>

      <Button
        title="Bearbeiten"
        variant="secondary"
        onPress={() => router.push(`/recipe/new?id=${recipe.id}`)}
      />
      <Button title="Löschen" variant="danger" onPress={confirmDelete} />
      <View style={{ height: Spacing.five }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  image: { width: '100%', height: 200, borderRadius: Spacing.three },
  tags: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.one },
  tag: {
    paddingHorizontal: Spacing.two,
    paddingVertical: Spacing.half,
    borderRadius: 999,
  },
});
