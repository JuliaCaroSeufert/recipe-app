import 'package:flutter/material.dart';

/// Vibrant, modern, friendly palette (teal-green + purple + pink accents).
class AppColors {
  static const green = Color(0xFF15B79E); // primary – fresh teal-green
  static const greenDeep = Color(0xFF0E9384);
  static const purple = Color(0xFF7A5AF8); // accent
  static const berry = Color(0xFF7A5AF8); // alias used for dinner/variety
  static const pink = Color(0xFFF6499B);
  static const coral = Color(0xFFFF6F4E);
  static const amber = Color(0xFFF79009);
  static const cream = Color(0xFFFBF7F1); // light background
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF231D2E);

  static const darkBg = Color(0xFF141218);
  static const darkCard = Color(0xFF211E29);

  /// Colourful hero gradient for headers / onboarding.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF17C3A2), Color(0xFF0E9384)],
  );

  /// Soft, pleasant tints for recipe/emoji tiles (deterministic per string).
  static const _tiles = [
    Color(0xFFFFE4D1), // peach
    Color(0xFFD6F3EA), // mint
    Color(0xFFE7E0FF), // lavender
    Color(0xFFFFE0EE), // blossom
    Color(0xFFFFF1CC), // butter
    Color(0xFFD6ECFB), // sky
    Color(0xFFE6F3D6), // pistachio
    Color(0xFFFCDDD2), // apricot
  ];

  static Color tileFor(String seed) {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _tiles[h % _tiles.length];
  }
}

ThemeData buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: brightness,
  );
  final scheme = base.copyWith(
    primary: AppColors.green,
    secondary: AppColors.purple,
    tertiary: AppColors.pink,
    surface: isLight ? AppColors.cream : AppColors.darkBg,
    surfaceContainer: isLight ? const Color(0xFFF4EEE4) : AppColors.darkCard,
    surfaceContainerHighest:
        isLight ? const Color(0xFFEDE6DA) : const Color(0xFF2C2838),
  );

  final text = _textTheme(scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Poppins',
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isLight ? AppColors.card : AppColors.darkCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primary,
      labelStyle: text.labelLarge,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isLight ? AppColors.card : AppColors.darkCard,
      elevation: 0,
      height: 68,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: scheme.outlineVariant),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      extendedTextStyle: text.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? AppColors.card : AppColors.darkCard,
      hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

TextTheme _textTheme(Color onSurface) {
  // Playful rounded display (Baloo2) for big headings, Poppins for the rest.
  TextStyle d(double size, FontWeight w, {double? h}) => TextStyle(
        fontFamily: 'Baloo2',
        fontSize: size,
        fontWeight: w,
        height: h,
        color: onSurface,
      );
  TextStyle p(double size, FontWeight w, {double? h, double? ls}) => TextStyle(
        fontFamily: 'Poppins',
        fontSize: size,
        fontWeight: w,
        height: h,
        letterSpacing: ls,
        color: onSurface,
      );
  return TextTheme(
    displaySmall: d(32, FontWeight.w700, h: 1.1),
    headlineMedium: d(27, FontWeight.w700, h: 1.15),
    headlineSmall: d(23, FontWeight.w600, h: 1.15),
    titleLarge: d(21, FontWeight.w600, h: 1.2),
    titleMedium: p(17, FontWeight.w600),
    titleSmall: p(15, FontWeight.w600),
    bodyLarge: p(16, FontWeight.w400, h: 1.4),
    bodyMedium: p(14, FontWeight.w400, h: 1.4),
    bodySmall: p(12.5, FontWeight.w400, h: 1.35),
    labelLarge: p(13.5, FontWeight.w500),
    labelMedium: p(12, FontWeight.w500),
    labelSmall: p(11, FontWeight.w500, ls: 0.2),
  );
}
