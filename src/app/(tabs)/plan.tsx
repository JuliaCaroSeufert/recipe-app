import { useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useMemo, useState } from 'react';
import { Alert, Pressable, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { Button, Card, Empty, Field, Screen } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import {
  confirmPlan,
  generatePlan,
  getLatestPlan,
  listAllTags,
  listRecipesForPlanning,
  PlanError,
  type GeneratedPick,
  type PlanRecipe,
  type PlanWithEntries,
} from '@/lib/plan';
import { isSupabaseConfigured } from '@/lib/supabase';
import type { PlanFilters } from '@/lib/types';

const DAY_NAMES = ['Tag 1', 'Tag 2', 'Tag 3', 'Tag 4', 'Tag 5', 'Tag 6', 'Tag 7',
  'Tag 8', 'Tag 9', 'Tag 10', 'Tag 11', 'Tag 12', 'Tag 13', 'Tag 14'];

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}
function toInt(s: string, fallback: number) {
  const n = parseInt(s.replace(/[^0-9]/g, ''), 10);
  return Number.isFinite(n) ? n : fallback;
}

export default function PlanScreen() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [recipes, setRecipes] = useState<PlanRecipe[]>([]);
  const [tags, setTags] = useState<string[]>([]);
  const [existingPlan, setExistingPlan] = useState<PlanWithEntries | null>(null);

  // filter form state
  const [persons, setPersons] = useState('2');
  const [days, setDays] = useState('7');
  const [mealsPerDay, setMealsPerDay] = useState('1');
  const [maxKcal, setMaxKcal] = useState('');
  const [includeTags, setIncludeTags] = useState<string[]>([]);
  const [excludeTags, setExcludeTags] = useState<string[]>([]);
  const [rules, setRules] = useState<{ tag: string; min: number }[]>([]);

  const [preview, setPreview] = useState<GeneratedPick[] | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [mode, setMode] = useState<'view' | 'edit'>('view');

  const load = useCallback(async () => {
    if (!isSupabaseConfigured) {
      setLoading(false);
      setError('Supabase nicht konfiguriert — siehe README (.env).');
      return;
    }
    try {
      setError(null);
      const [rs, ts, plan] = await Promise.all([
        listRecipesForPlanning(),
        listAllTags(),
        getLatestPlan(),
      ]);
      setRecipes(rs);
      setTags(ts);
      setExistingPlan(plan);
      setMode(plan ? 'view' : 'edit');
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

  const filters: PlanFilters = useMemo(() => {
    const f: PlanFilters = {
      days: clamp(toInt(days, 7), 1, 14),
      mealsPerDay: clamp(toInt(mealsPerDay, 1), 1, 5),
    };
    const kcal = toInt(maxKcal, 0);
    if (maxKcal.trim() && kcal > 0) f.maxKcalPerServing = kcal;
    if (includeTags.length) f.includeTags = includeTags;
    if (excludeTags.length) f.excludeTags = excludeTags;
    if (rules.length) f.tagRules = rules.map((r) => ({ tag: r.tag, min: r.min }));
    return f;
  }, [days, mealsPerDay, maxKcal, includeTags, excludeTags, rules]);

  function toggle(list: string[], set: (v: string[]) => void, tag: string) {
    set(list.includes(tag) ? list.filter((t) => t !== tag) : [...list, tag]);
  }

  function toggleRule(tag: string) {
    setRules((prev) =>
      prev.some((r) => r.tag === tag)
        ? prev.filter((r) => r.tag !== tag)
        : [...prev, { tag, min: 1 }],
    );
  }
  function setRuleMin(tag: string, min: number) {
    setRules((prev) =>
      prev.map((r) => (r.tag === tag ? { ...r, min: clamp(min, 1, 14) } : r)),
    );
  }

  function generate() {
    try {
      const picks = generatePlan(recipes, filters);
      setPreview(picks);
    } catch (e) {
      if (e instanceof PlanError) {
        Alert.alert('Plan nicht möglich', e.message);
      } else {
        Alert.alert('Fehler', e instanceof Error ? e.message : String(e));
      }
    }
  }

  async function confirm() {
    if (!preview) return;
    setConfirming(true);
    try {
      const p = clamp(toInt(persons, 2), 1, 50);
      await confirmPlan({
        title: `Wochenplan (${filters.days} Tage)`,
        startDate: new Date().toISOString().slice(0, 10),
        days: filters.days ?? 7,
        mealsPerDay: filters.mealsPerDay ?? 1,
        servings: p,
        filters,
        picks: preview,
      });
      setPreview(null);
      await load();
      Alert.alert(
        'Wochenplan bestätigt',
        'Die Einkaufsliste wurde erstellt — siehe Tab „Einkauf“.',
      );
    } catch (e) {
      Alert.alert('Fehler', e instanceof Error ? e.message : String(e));
    } finally {
      setConfirming(false);
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
        <Empty title="Kann Wochenplan nicht laden" hint={error} />
      </Screen>
    );
  }
  if (recipes.length === 0) {
    return (
      <Screen>
        <Empty
          title="Noch keine Rezepte"
          hint="Lege zuerst ein paar Rezepte an, dann kann ich daraus einen Wochenplan bauen."
        />
        <Button title="Zu den Rezepten" onPress={() => router.push('/')} />
      </Screen>
    );
  }

  // --- confirmed / existing plan overview ---
  if (mode === 'view' && existingPlan && !preview) {
    const p = existingPlan.plan;
    return (
      <Screen>
        <ThemedText type="subtitle">{p.title}</ThemedText>
        <ThemedText type="small" themeColor="textSecondary">
          {p.servings} Personen · {p.days} Tage · {p.meals_per_day} Mahlzeit(en)/Tag
          {p.status === 'confirmed' ? ' · bestätigt' : ''}
        </ThemedText>

        <PlanOverview
          days={p.days}
          mealsPerDay={p.meals_per_day}
          items={existingPlan.entries.map((e) => ({
            dayIndex: e.day_index,
            slotIndex: e.slot_index,
            title: e.recipe?.title ?? 'Rezept',
            kcal: e.recipe?.kcal_per_serving ?? null,
          }))}
        />

        <Button title="Zur Einkaufsliste" onPress={() => router.push('/shopping')} />
        <Button
          title="Neuen Plan erstellen"
          variant="secondary"
          onPress={() => {
            setPreview(null);
            setMode('edit');
          }}
        />
        <View style={{ height: Spacing.five }} />
      </Screen>
    );
  }

  // --- preview of a freshly generated plan ---
  if (preview) {
    return (
      <Screen>
        <ThemedText type="subtitle">Vorschau</ThemedText>
        <ThemedText type="small" themeColor="textSecondary">
          {clamp(toInt(persons, 2), 1, 50)} Personen · {filters.days} Tage ·{' '}
          {filters.mealsPerDay} Mahlzeit(en)/Tag
        </ThemedText>

        <PlanOverview
          days={filters.days ?? 7}
          mealsPerDay={filters.mealsPerDay ?? 1}
          items={preview.map((p) => ({
            dayIndex: p.dayIndex,
            slotIndex: p.slotIndex,
            title: p.recipe.title,
            kcal: p.recipe.kcal_per_serving,
          }))}
        />

        <Button
          title="Bestätigen & Einkaufsliste erstellen"
          loading={confirming}
          onPress={confirm}
        />
        <Button title="Neu generieren" variant="secondary" onPress={generate} />
        <Button title="Filter ändern" variant="ghost" onPress={() => setPreview(null)} />
        <View style={{ height: Spacing.five }} />
      </Screen>
    );
  }

  // --- filter form ---
  return (
    <Screen>
      <ThemedText type="subtitle">Neuer Wochenplan</ThemedText>
      <ThemedText type="small" themeColor="textSecondary">
        {recipes.length} Rezepte im Speicher.
      </ThemedText>

      <Card>
        <ThemedText type="smallBold">Personen & Zeitraum</ThemedText>
        <Row>
          <View style={styles.flex}>
            <Field
              label="Personen"
              keyboardType="numeric"
              value={persons}
              onChangeText={setPersons}
            />
          </View>
          <View style={styles.flex}>
            <Field
              label="Tage (1–14)"
              keyboardType="numeric"
              value={days}
              onChangeText={setDays}
            />
          </View>
          <View style={styles.flex}>
            <Field
              label="Mahlzeiten/Tag"
              keyboardType="numeric"
              value={mealsPerDay}
              onChangeText={setMealsPerDay}
            />
          </View>
        </Row>
        <ThemedText type="small" themeColor="textSecondary">
          Personenzahl gilt einmalig für die ganze Woche.
        </ThemedText>
      </Card>

      <Card>
        <ThemedText type="smallBold">Kalorien</ThemedText>
        <Field
          label="Max. kcal pro Portion (optional)"
          keyboardType="numeric"
          value={maxKcal}
          onChangeText={setMaxKcal}
          placeholder="z. B. 500"
        />
        {maxKcal.trim() ? (
          <ThemedText type="small" themeColor="textSecondary">
            Rezepte ohne kcal-Angabe werden bei aktivem Limit ausgelassen.
          </ThemedText>
        ) : null}
      </Card>

      {tags.length > 0 && (
        <>
          <Card>
            <ThemedText type="smallBold">Nur Rezepte mit diesen Tags</ThemedText>
            <Chips
              tags={tags}
              active={includeTags}
              onToggle={(t) => toggle(includeTags, setIncludeTags, t)}
            />
          </Card>

          <Card>
            <ThemedText type="smallBold">Rezepte mit diesen Tags ausschließen</ThemedText>
            <Chips
              tags={tags}
              active={excludeTags}
              onToggle={(t) => toggle(excludeTags, setExcludeTags, t)}
            />
          </Card>

          <Card>
            <ThemedText type="smallBold">Tag-Regeln (Mindestanzahl)</ThemedText>
            <ThemedText type="small" themeColor="textSecondary">
              z. B. mindestens 3× „bake and dump“ pro Plan.
            </ThemedText>
            <Chips
              tags={tags}
              active={rules.map((r) => r.tag)}
              onToggle={toggleRule}
            />
            {rules.map((r) => (
              <View key={r.tag} style={styles.ruleRow}>
                <ThemedText type="small" style={styles.flex}>
                  mind. {r.min}× {r.tag}
                </ThemedText>
                <Stepper
                  value={r.min}
                  onChange={(v) => setRuleMin(r.tag, v)}
                />
              </View>
            ))}
          </Card>
        </>
      )}

      <Button title="Plan generieren" onPress={generate} />
      {existingPlan ? (
        <Button
          title="Abbrechen"
          variant="ghost"
          onPress={() => setMode('view')}
        />
      ) : null}
      <View style={{ height: Spacing.five }} />
    </Screen>
  );
}

// --- small building blocks --------------------------------------------------

function Row({ children }: { children: React.ReactNode }) {
  return <View style={styles.row}>{children}</View>;
}

function Chips({
  tags,
  active,
  onToggle,
}: {
  tags: string[];
  active: string[];
  onToggle: (tag: string) => void;
}) {
  const theme = useTheme();
  return (
    <View style={styles.chips}>
      {tags.map((t) => {
        const on = active.includes(t);
        return (
          <Pressable
            key={t}
            onPress={() => onToggle(t)}
            style={[
              styles.chip,
              {
                backgroundColor: on ? '#3c87f7' : theme.backgroundSelected,
              },
            ]}>
            <ThemedText type="small" style={{ color: on ? '#fff' : theme.text }}>
              {t}
            </ThemedText>
          </Pressable>
        );
      })}
    </View>
  );
}

function Stepper({
  value,
  onChange,
}: {
  value: number;
  onChange: (v: number) => void;
}) {
  const theme = useTheme();
  return (
    <View style={styles.stepper}>
      <Pressable
        onPress={() => onChange(value - 1)}
        style={[styles.stepBtn, { backgroundColor: theme.backgroundSelected }]}>
        <ThemedText type="smallBold">−</ThemedText>
      </Pressable>
      <ThemedText type="smallBold" style={styles.stepVal}>
        {value}
      </ThemedText>
      <Pressable
        onPress={() => onChange(value + 1)}
        style={[styles.stepBtn, { backgroundColor: theme.backgroundSelected }]}>
        <ThemedText type="smallBold">+</ThemedText>
      </Pressable>
    </View>
  );
}

interface OverviewItem {
  dayIndex: number;
  slotIndex: number;
  title: string;
  kcal: number | null;
}

function PlanOverview({
  days,
  mealsPerDay,
  items,
}: {
  days: number;
  mealsPerDay: number;
  items: OverviewItem[];
}) {
  return (
    <View style={styles.overview}>
      {Array.from({ length: days }, (_, day) => {
        const dayItems = items
          .filter((i) => i.dayIndex === day)
          .sort((a, b) => a.slotIndex - b.slotIndex);
        return (
          <Card key={day}>
            <ThemedText type="smallBold">{DAY_NAMES[day] ?? `Tag ${day + 1}`}</ThemedText>
            {dayItems.length === 0 ? (
              <ThemedText type="small" themeColor="textSecondary">
                —
              </ThemedText>
            ) : (
              dayItems.map((i) => (
                <ThemedText key={i.slotIndex} type="small">
                  {mealsPerDay > 1 ? `${i.slotIndex + 1}. ` : ''}
                  {i.title}
                  {i.kcal ? ` · ${i.kcal} kcal` : ''}
                </ThemedText>
              ))
            )}
          </Card>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  row: { flexDirection: 'row', gap: Spacing.two },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.one },
  chip: {
    paddingHorizontal: Spacing.two,
    paddingVertical: Spacing.one,
    borderRadius: 999,
  },
  ruleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.two,
  },
  stepper: { flexDirection: 'row', alignItems: 'center', gap: Spacing.two },
  stepBtn: {
    width: 32,
    height: 32,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepVal: { minWidth: 20, textAlign: 'center' },
  overview: { gap: Spacing.two },
});
