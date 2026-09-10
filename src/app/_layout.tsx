import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useColorScheme } from 'react-native';

SplashScreen.preventAutoHideAsync();
SplashScreen.hideAsync();

export default function RootLayout() {
  const colorScheme = useColorScheme();
  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <Stack>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen
          name="recipe/new"
          options={{ title: 'Rezept', presentation: 'modal' }}
        />
        <Stack.Screen
          name="recipe/instagram"
          options={{ title: 'Instagram importieren', presentation: 'modal' }}
        />
        <Stack.Screen name="recipe/[id]" options={{ title: 'Rezept' }} />
        <Stack.Screen name="rewe" options={{ title: 'Bei REWE bestellen' }} />
      </Stack>
    </ThemeProvider>
  );
}
