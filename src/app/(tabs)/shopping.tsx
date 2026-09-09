import { Empty, Screen } from '@/components/ui';

export default function ShoppingScreen() {
  return (
    <Screen>
      <Empty
        title="Einkauf"
        hint="Kommt in Phase 5: aus dem bestätigten Wochenplan wird die Einkaufsliste erzeugt — Mengen über alle Rezepte zusammengefasst und auf die Personenzahl skaliert. REWE-Bestellung folgt in Phase 6."
      />
    </Screen>
  );
}
