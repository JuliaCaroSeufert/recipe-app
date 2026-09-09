import { Empty, Screen } from '@/components/ui';

export default function PlanScreen() {
  return (
    <Screen>
      <Empty
        title="Wochenplan"
        hint="Kommt in Phase 4: Filter setzen (Tage, Mahlzeiten/Tag, Tag-Regeln, kcal), Plan generieren, Personenzahl festlegen, bestätigen."
      />
    </Screen>
  );
}
