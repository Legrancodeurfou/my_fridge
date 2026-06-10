import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF029834);
  static const softGreen = Color(0xFF90CC93);
  static const background = Color(0xFFF5F5F0);
  static const surface = Color(0xFFF0FFF0);
  static const textPrimary = Color(0xFF1F2933);
  static const textSecondary = Color(0xFF636A77);
  static const expiringSoon = Color(0xFFF79F1D);
  static const expired = Color(0xFFDF2935);

  static const card = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFFCFCF9);
  static const surfaceHigh = Color(0xFFF1F2EE);
  static const surfaceHighest = Color(0xFFE9EBE7);
  static const outline = Color(0xFF8A929B);
  static const outlineVariant = Color(0xFFD9DDD7);
  static const shadow = Color(0xFF1F2933);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.surface,
          onPrimaryContainer: AppColors.textPrimary,
          secondary: AppColors.softGreen,
          onSecondary: AppColors.textPrimary,
          secondaryContainer: AppColors.surface,
          onSecondaryContainer: AppColors.textPrimary,
          tertiary: AppColors.expiringSoon,
          onTertiary: AppColors.textPrimary,
          error: AppColors.expired,
          onError: Colors.white,
          errorContainer: const Color(0xFFFFDAD9),
          onErrorContainer: const Color(0xFF410006),
          surface: AppColors.card,
          onSurface: AppColors.textPrimary,
          surfaceContainerLowest: AppColors.background,
          surfaceContainerLow: AppColors.surfaceLow,
          surfaceContainer: AppColors.card,
          surfaceContainerHigh: AppColors.surfaceHigh,
          surfaceContainerHighest: AppColors.surfaceHighest,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
          shadow: AppColors.shadow,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'PlusJakartaSans',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = base.textTheme
        .apply(
          fontFamily: 'PlusJakartaSans',
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.85),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surfaceLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.surface,
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.9),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
