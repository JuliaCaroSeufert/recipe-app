import { forwardRef } from 'react';
import {
  ActivityIndicator,
  Pressable,
  type PressableProps,
  ScrollView,
  StyleSheet,
  TextInput,
  type TextInputProps,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

export function Screen({
  children,
  scroll = true,
  edges,
}: {
  children: React.ReactNode;
  scroll?: boolean;
  edges?: ('top' | 'bottom' | 'left' | 'right')[];
}) {
  const theme = useTheme();
  const Body = scroll ? ScrollView : View;
  return (
    <SafeAreaView
      style={[styles.flex, { backgroundColor: theme.background }]}
      edges={edges ?? ['top', 'left', 'right']}>
      <Body
        style={styles.flex}
        contentContainerStyle={scroll ? styles.scrollContent : undefined}>
        {children}
      </Body>
    </SafeAreaView>
  );
}

export const Field = forwardRef<TextInput, TextInputProps & { label?: string }>(
  ({ label, style, ...props }, ref) => {
    const theme = useTheme();
    return (
      <View style={styles.field}>
        {label ? (
          <ThemedText type="smallBold" style={styles.label}>
            {label}
          </ThemedText>
        ) : null}
        <TextInput
          ref={ref}
          placeholderTextColor={theme.textSecondary}
          style={[
            styles.input,
            {
              color: theme.text,
              backgroundColor: theme.backgroundElement,
              borderColor: theme.backgroundSelected,
            },
            style,
          ]}
          {...props}
        />
      </View>
    );
  },
);
Field.displayName = 'Field';

export function Button({
  title,
  onPress,
  variant = 'primary',
  loading = false,
  disabled = false,
  style,
}: {
  title: string;
  onPress: PressableProps['onPress'];
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  loading?: boolean;
  disabled?: boolean;
  style?: PressableProps['style'];
}) {
  const theme = useTheme();
  const bg =
    variant === 'primary'
      ? '#3c87f7'
      : variant === 'danger'
        ? '#e5484d'
        : variant === 'secondary'
          ? theme.backgroundElement
          : 'transparent';
  const fg =
    variant === 'primary' || variant === 'danger' ? '#fff' : theme.text;
  return (
    <Pressable
      onPress={disabled || loading ? undefined : onPress}
      style={[
        styles.button,
        { backgroundColor: bg, opacity: disabled ? 0.5 : 1 },
        style as object,
      ]}>
      {loading ? (
        <ActivityIndicator color={fg} />
      ) : (
        <ThemedText type="smallBold" style={{ color: fg }}>
          {title}
        </ThemedText>
      )}
    </Pressable>
  );
}

export function Card({ children }: { children: React.ReactNode }) {
  const theme = useTheme();
  return (
    <View style={[styles.card, { backgroundColor: theme.backgroundElement }]}>
      {children}
    </View>
  );
}

export function Empty({ title, hint }: { title: string; hint?: string }) {
  return (
    <View style={styles.empty}>
      <ThemedText type="subtitle" style={styles.emptyTitle}>
        {title}
      </ThemedText>
      {hint ? (
        <ThemedText type="small" themeColor="textSecondary" style={styles.center}>
          {hint}
        </ThemedText>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  scrollContent: { padding: Spacing.three, gap: Spacing.three },
  field: { gap: Spacing.one },
  label: { marginLeft: Spacing.half },
  input: {
    borderRadius: Spacing.two,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    fontSize: 16,
    minHeight: 44,
  },
  button: {
    minHeight: 48,
    borderRadius: Spacing.two,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.four,
  },
  card: { borderRadius: Spacing.three, padding: Spacing.three, gap: Spacing.two },
  empty: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: Spacing.five,
    gap: Spacing.two,
    minHeight: 320,
  },
  emptyTitle: { textAlign: 'center' },
  center: { textAlign: 'center' },
});
