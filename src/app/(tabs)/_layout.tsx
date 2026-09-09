import { Tabs } from 'expo-router';
import { type ColorValue, Text } from 'react-native';

import { useTheme } from '@/hooks/use-theme';

function Icon({ emoji, color }: { emoji: string; color: ColorValue }) {
  return <Text style={{ fontSize: 20, color }}>{emoji}</Text>;
}

export default function TabsLayout() {
  const theme = useTheme();
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: theme.text,
        tabBarInactiveTintColor: theme.textSecondary,
        tabBarStyle: { backgroundColor: theme.background },
        headerStyle: { backgroundColor: theme.background },
        headerTintColor: theme.text,
      }}>
      <Tabs.Screen
        name="index"
        options={{
          title: 'Rezepte',
          tabBarIcon: ({ color }) => <Icon emoji="📖" color={color} />,
        }}
      />
      <Tabs.Screen
        name="plan"
        options={{
          title: 'Wochenplan',
          tabBarIcon: ({ color }) => <Icon emoji="🗓" color={color} />,
        }}
      />
      <Tabs.Screen
        name="shopping"
        options={{
          title: 'Einkauf',
          tabBarIcon: ({ color }) => <Icon emoji="🛒" color={color} />,
        }}
      />
    </Tabs>
  );
}
