import 'package:flutter/material.dart';

/// KosManage visual system translated from the Figma Make reference.
/// Keep the theme centralized so owner and tenant screens stay consistent.
class AppTheme {
  static const brand = Color(0xFFE71946);
  static const brandSoft = Color(0xFFFFF0F3);
  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF777985);
  static const canvas = Color(0xFFF7F7FA);
  static const border = Color(0xFFE9E9EF);
  static const success = Color(0xFF22A06B);
  static const warning = Color(0xFFF2A93B);
  static const danger = Color(0xFFD92D20);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: brandSoft,
      onPrimaryContainer: brand,
      secondary: ink,
      onSecondary: Colors.white,
      surface: canvas,
      onSurface: ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainer: Colors.white,
      surfaceContainerHigh: const Color(0xFFF2F3F7),
      surfaceContainerHighest: const Color(0xFFF2F3F7),
      outline: border,
      outlineVariant: border,
      error: danger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFE7E8),
      onErrorContainer: const Color(0xFF9F1D2D),
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
      primary: const Color(0xFFFF5979),
      onPrimary: const Color(0xFF3A0010),
      primaryContainer: const Color(0xFF5B1024),
      onPrimaryContainer: const Color(0xFFFFD9E0),
      secondary: const Color(0xFFE8E8EC),
      surface: const Color(0xFF111114),
      onSurface: const Color(0xFFF4F4F6),
      surfaceContainerLowest: const Color(0xFF111114),
      surfaceContainer: const Color(0xFF19191E),
      surfaceContainerHigh: const Color(0xFF24242A),
      surfaceContainerHighest: const Color(0xFF24242A),
      outline: const Color(0xFF3A3A42),
      outlineVariant: const Color(0xFF33333A),
      error: const Color(0xFFFF6B6B),
      onError: const Color(0xFF3B0000),
      errorContainer: const Color(0xFF5B1F25),
      onErrorContainer: const Color(0xFFFFDAD7),
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final borderColor = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.62 : 0.82,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.45,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? scheme.surfaceContainer : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.25),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        labelStyle: TextStyle(
          fontSize: 14,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 74,
        backgroundColor: isDark ? scheme.surfaceContainer : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark ? scheme.primaryContainer : brandSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 50),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 48),
          foregroundColor: scheme.primary,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 44),
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide.none,
      ),
    );
  }
}
