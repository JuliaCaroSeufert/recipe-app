import 'package:flutter/material.dart';

/// Central colour palette — fresh, appetising, friendly.
class AppColors {
  static const green = Color(0xFF1E9E63); // primary (fresh herb green)
  static const greenDeep = Color(0xFF147A4B);
  static const coral = Color(0xFFFF6F4E); // warm accent
  static const amber = Color(0xFFF6A723); // lunch / energy
  static const berry = Color(0xFF8E5BD9); // dinner / variety
  static const cream = Color(0xFFFBF6EE); // light background
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF241F1A);

  static const darkBg = Color(0xFF14130F);
  static const darkCard = Color(0xFF211E18);

  /// A small, pleasant palette used to tint recipe/emoji tiles so lists feel
  /// lively even without photos. Deterministic per string.
  static const _tiles = [
    Color(0xFFFFE8D6), // peach
    Color(0xFFDEF2E0), // mint
    Color(0xFFFCE4D6), // apricot
    Color(0xFFE7E3FB), // lavender
    Color(0xFFFFF0C9), // butter
    Color(0xFFD9EEF6), // sky
    Color(0xFFFADDE1), // blossom
    Color(0xFFE6F0D4), // pistachio
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
    secondary: AppColors.coral,
    tertiary: AppColors.amber,
    surface: isLight ? AppColors.cream : AppColors.darkBg,
    surfaceContainer: isLight ? const Color(0xFFF5EEE3) : AppColors.darkCard,
    surfaceContainerHighest:
        isLight ? const Color(0xFFEFE7D9) : const Color(0xFF2B2720),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primary,
      labelStyle: text.labelLarge,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isLight ? AppColors.card : AppColors.darkCard,
      elevation: 0,
      height: 66,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: scheme.outlineVariant),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      extendedTextStyle: text.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
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
  TextStyle s(double size, FontWeight w, {double? h, double? ls}) => TextStyle(
        fontFamily: 'Poppins',
        fontSize: size,
        fontWeight: w,
        height: h,
        letterSpacing: ls,
        color: onSurface,
      );
  return TextTheme(
    displaySmall: s(30, FontWeight.w700, h: 1.15),
    headlineMedium: s(26, FontWeight.w700, h: 1.2),
    headlineSmall: s(22, FontWeight.w600, h: 1.2),
    titleLarge: s(20, FontWeight.w600, h: 1.25),
    titleMedium: s(17, FontWeight.w600),
    titleSmall: s(15, FontWeight.w600),
    bodyLarge: s(16, FontWeight.w400, h: 1.4),
    bodyMedium: s(14, FontWeight.w400, h: 1.4),
    bodySmall: s(12.5, FontWeight.w400, h: 1.35),
    labelLarge: s(13.5, FontWeight.w500),
    labelMedium: s(12, FontWeight.w500),
    labelSmall: s(11, FontWeight.w500, ls: 0.2),
  );
}
