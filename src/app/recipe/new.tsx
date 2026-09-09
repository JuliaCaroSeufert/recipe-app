import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { Alert, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { Button, Field, Screen } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { parseIngredientLine, splitIngredientBlock } from '@/lib/parse';
import {
  createRecipe,
  getRecipe,
  type RecipeInput,
  updateRecipe,
} from '@/lib/recipes';

function toInt(s: string): number | null {
  const n = parseInt(s, 10);
  return Number.isFinite(n) ? n : null;
}

export default function RecipeFormScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const editing = Boolean(id);

  const [title, setTitle] = useState('');
  const [servings, setServings] = useState('2');
  const [kcal, setKcal] = useState('');
  const [prep, setPrep] = useState('');
  const [description, setDescription] = useState('');
  const [ingredientsText, setIngredientsText] = useState('');
  const [stepsText, setStepsText] = useState('');
  const [tagsText, setTagsText] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(editing);

  useEffect(() => {
    if (!id) return;
    (async () => {
      try {
        const r = await getRecipe(id);
        if (!r) return;
        setTitle(r.title);
        setServings(String(r.servings));
        setKcal(r.kcal_per_serving ? String(r.kcal_per_serving) : '');
        setPrep(r.prep_minutes ? String(r.prep_minutes) : '');
        setDescription(r.description ?? '');
        setIngredientsText(
          r.ingredients
            .map(
              (ri) =>
                ri.raw_text ??
                [ri.quantity, ri.unit, ri.ingredient.name]
                  .filter(Boolean)
                  .join(' '),
            )
            .join('\n'),
        );
        setStepsText(r.steps.join('\n'));
        setTagsText(r.tags.map((t) => t.name).join(', '));
      } finally {
        setLoading(false);
      }
    })();
  }, [id]);

  const parsedPreview = useMemo(
    () => splitIngredientBlock(ingredientsText).map(parseIngredientLine),
    [ingredientsText],
  );

  async function save() {
    if (!title.trim()) {
      Alert.alert('Titel fehlt', 'Bitte einen Rezepttitel eingeben.');
      return;
    }
    const input: RecipeInput = {
      title,
      description: description.trim() || null,
      servings: toInt(servings) ?? 2,
      kcal_per_serving: toInt(kcal),
      prep_minutes: toInt(prep),
      steps: stepsText
        .split(/\r?\n/)
        .map((s) => s.replace(/^\d+[.)]\s*/, '').trim())
        .filter(Boolean),
      ingredients: parsedPreview.map((p) => ({
        name: p.name,
        quantity: p.quantity,
        unit: p.unit,
        note: p.note,
        raw_text: p.raw,
      })),
      tags: tagsText
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean),
    };

    setSaving(true);
    try {
      if (editing && id) {
        await updateRecipe(id, input);
        router.back();
      } else {
        const newId = await createRecipe(input);
        router.replace(`/recipe/${newId}`);
      }
    } catch (e) {
      Alert.alert('Speichern fehlgeschlagen', String(e));
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <Screen>
        <ThemedText>Lädt…</ThemedText>
      </Screen>
    );
  }

  return (
    <Screen>
      <Stack.Screen
        options={{ title: editing ? 'Rezept bearbeiten' : 'Neues Rezept' }}
      />

      <Field label="Titel" value={title} onChangeText={setTitle} />

      <View style={styles.row}>
        <View style={styles.col}>
          <Field
            label="Portionen"
            value={servings}
            onChangeText={setServings}
            keyboardType="number-pad"
          />
        </View>
        <View style={styles.col}>
          <Field
            label="kcal / Portion"
            value={kcal}
            onChangeText={setKcal}
            keyboardType="number-pad"
            placeholder="optional"
          />
        </View>
        <View style={styles.col}>
          <Field
            label="Min."
            value={prep}
            onChangeText={setPrep}
            keyboardType="number-pad"
            placeholder="optional"
          />
        </View>
      </View>

      <Field
        label="Beschreibung"
        value={description}
        onChangeText={setDescription}
        placeholder="optional"
        multiline
        style={styles.multiline}
      />

      <Field
        label="Zutaten (eine pro Zeile, z. B. „200 g Feta, gewürfelt“)"
        value={ingredientsText}
        onChangeText={setIngredientsText}
        multiline
        style={styles.multiline}
        autoCapitalize="none"
      />

      {parsedPreview.length > 0 && (
        <View style={styles.preview}>
          <ThemedText type="smallBold">Erkannt:</ThemedText>
          {parsedPreview.map((p, i) => (
            <ThemedText key={i} type="small" themeColor="textSecondary">
              • {p.quantity ?? '—'} {p.unit ?? ''} {p.name}
              {p.note ? ` (${p.note})` : ''}
            </ThemedText>
          ))}
        </View>
      )}

      <Field
        label="Zubereitung (ein Schritt pro Zeile)"
        value={stepsText}
        onChangeText={setStepsText}
        multiline
        style={styles.multiline}
      />

      <Field
        label="Tags (kommagetrennt, z. B. „bake and dump, unter 500 kcal“)"
        value={tagsText}
        onChangeText={setTagsText}
        autoCapitalize="none"
      />

      <Button
        title={editing ? 'Änderungen speichern' : 'Rezept speichern'}
        onPress={save}
        loading={saving}
      />
      <View style={{ height: Spacing.five }} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: Spacing.two },
  col: { flex: 1 },
  multiline: { minHeight: 96, textAlignVertical: 'top', paddingTop: Spacing.two },
  preview: { gap: 2, paddingHorizontal: Spacing.half },
});
