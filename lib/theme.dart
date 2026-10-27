import 'package:flutter/material.dart';

abstract final class BirrColors {
  static const ivory = Color(0xFFFBF9F4);
  static const ivoryDeep = Color(0xFFF3EFE6);
  static const outline = Color(0xFF8C887C);
  static const outlineVariant = Color(0xFFECE7DD);
  static const forest = Color(0xFF1B4332);
  static const forestDark = Color(0xFF0E281E);
  static const forestSoft = Color(0xFFD8EBDD);
  static const goldDecor = Color(0xFFC89D47);
  static const goldDeep = Color(0xFF8A6A1F);
  static const goldSoft = Color(0xFFF6EBD0);
  static const onGoldSoft = Color(0xFF3F2E00);
  static const ink = Color(0xFF1C1B17);
  static const inkSecondary = Color(0xFF5F5B50);
  static const income = Color(0xFF2D6A4F);
  static const expense = Color(0xFFA4442A);
  static const dangerSoft = Color(0xFFFBE3DC);
  static const onDangerSoft = Color(0xFF8A2E17);
  static const goldOnDark = Color(0xFFE3C27A);
  static const incomeOnDark = Color(0xFF8FDDB1);
  static const expenseOnDark = Color(0xFFF4B29E);
  static const heroText = Color(0xFFFFFFFF);
  static const heroTrack = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF0F1712);
  static const darkSurface = Color(0xFF17231C);
  static const darkSurfaceVariant = Color(0xFF1F2D25);
  static const darkOutlineVariant = Color(0xFF2A3A31);
}

ThemeData birrTheme({required bool dark, required bool amharic}) {
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Color(0xFF8FDDB1),
          onPrimary: Color(0xFF0E281E),
          primaryContainer: Color(0xFF1F382A),
          onPrimaryContainer: Color(0xFFBDEBCB),
          secondary: Color(0xFFE3C27A),
          onSecondary: Color(0xFF3F2E00),
          surface: BirrColors.darkSurface,
          onSurface: Color(0xFFF2F1EA),
          surfaceContainerHighest: BirrColors.darkSurfaceVariant,
          onSurfaceVariant: Color(0xFFC4C9C1),
          outline: Color(0xFF929A92),
          outlineVariant: BirrColors.darkOutlineVariant,
          error: Color(0xFFF4B29E),
          errorContainer: Color(0xFF492A23),
        )
      : const ColorScheme.light(
          primary: BirrColors.forest,
          onPrimary: BirrColors.ivory,
          primaryContainer: BirrColors.forestSoft,
          onPrimaryContainer: BirrColors.forestDark,
          secondary: BirrColors.goldDeep,
          onSecondary: Colors.white,
          secondaryContainer: BirrColors.goldSoft,
          onSecondaryContainer: BirrColors.onGoldSoft,
          surface: Colors.white,
          onSurface: BirrColors.ink,
          surfaceContainerHighest: BirrColors.ivoryDeep,
          onSurfaceVariant: BirrColors.inkSecondary,
          outline: BirrColors.outline,
          outlineVariant: BirrColors.outlineVariant,
          error: BirrColors.expense,
          errorContainer: BirrColors.dangerSoft,
        );

  TextStyle text(
    double size, {
    FontWeight weight = FontWeight.normal,
    bool serif = false,
  }) =>
      TextStyle(
        fontFamily: serif ? 'serif' : null,
        fontSize: size,
        fontWeight: weight,
        height: amharic ? 1.45 : 1.3,
        letterSpacing: amharic ? 0 : null,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? BirrColors.darkBackground : BirrColors.ivory,
    fontFamily: null,
    textTheme: TextTheme(
      headlineSmall: text(22, weight: FontWeight.bold, serif: true),
      titleLarge: text(20, weight: FontWeight.bold, serif: true),
      titleMedium: text(16, weight: FontWeight.w600),
      bodyLarge: text(16),
      bodyMedium: text(14),
      bodySmall: text(12),
      labelLarge: text(14, weight: FontWeight.w600),
      labelMedium: text(12, weight: FontWeight.w600),
      labelSmall: text(11, weight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: .55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text(11, weight: FontWeight.w600)),
    ),
  );
}
