import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Shared theme for the Customer and Seller apps — the Homely design system.
///
/// Poppins carries display/headings; Nunito carries body and labels — a warm,
/// rounded, humanist pairing. The palette lives in [HomelyColors]; this file
/// wires it into a Material 3 [ThemeData]. Homely commits to one warm daylight
/// world, so there is no dark theme by design.
class AppTheme {
  AppTheme._();

  static const _radius = 14.0;
  static const _cardRadius = 18.0;

  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: HomelyColors.blueDeep,
      onPrimary: Colors.white,
      primaryContainer: HomelyColors.blueTint,
      onPrimaryContainer: HomelyColors.blueDeep,
      secondary: HomelyColors.gold,
      onSecondary: HomelyColors.ink,
      secondaryContainer: HomelyColors.goldTint,
      onSecondaryContainer: HomelyColors.goldDeep,
      tertiary: HomelyColors.sage,
      onTertiary: Colors.white,
      tertiaryContainer: HomelyColors.sageTint,
      onTertiaryContainer: HomelyColors.sageDeep,
      error: HomelyColors.danger,
      onError: Colors.white,
      surface: HomelyColors.surface,
      onSurface: HomelyColors.ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: HomelyColors.cream,
      surfaceContainer: HomelyColors.cream,
      surfaceContainerHigh: HomelyColors.surfaceAlt,
      surfaceContainerHighest: HomelyColors.surfaceAlt,
      onSurfaceVariant: HomelyColors.inkSoft,
      outline: HomelyColors.inkFaint,
      outlineVariant: HomelyColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: HomelyColors.cream,
      textTheme: _textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: HomelyColors.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: HomelyColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: HomelyColors.ink,
        ),
      ),

      // Primary CTA = Trust Blue (non-food actions: Sign Up, Track, Save…).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HomelyColors.blueDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: HomelyColors.inkFaint.withValues(alpha: 0.25),
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HomelyColors.blueDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HomelyColors.blueDeep,
          side: const BorderSide(color: HomelyColors.blue, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HomelyColors.blueDeep,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HomelyColors.surface,
        hintStyle: const TextStyle(color: HomelyColors.inkFaint),
        prefixIconColor: HomelyColors.blueDeep,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: HomelyColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: HomelyColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: HomelyColors.blueDeep, width: 1.6),
        ),
      ),

      cardTheme: CardThemeData(
        color: HomelyColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: const BorderSide(color: HomelyColors.lineSoft),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: HomelyColors.surface,
        selectedColor: HomelyColors.ink,
        checkmarkColor: HomelyColors.cream,
        side: const BorderSide(color: HomelyColors.line),
        // Label follows selection: cream on the dark selected chip, ink on the
        // light unselected one. RawChip resolves a WidgetStateColor per-state.
        labelStyle: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? HomelyColors.cream
                  : HomelyColors.ink),
        ),
        secondaryLabelStyle: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: HomelyColors.cream,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? HomelyColors.sage
              : HomelyColors.inkFaint.withValues(alpha: 0.4),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      dividerTheme: const DividerThemeData(
        color: HomelyColors.line,
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: HomelyColors.surface,
        selectedItemColor: HomelyColors.blueDeep,
        unselectedItemColor: HomelyColors.inkFaint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: HomelyColors.surface,
        indicatorColor: HomelyColors.blueTint,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: HomelyColors.blueDeep),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HomelyColors.ink,
        contentTextStyle: const TextStyle(color: HomelyColors.cream),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HomelyColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HomelyColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ── Typography: Poppins (display/titles) + Nunito (body/labels) ────────
  static TextTheme get _textTheme {
    final base = ThemeData(brightness: Brightness.light).textTheme;
    final poppins = GoogleFonts.poppinsTextTheme(base);
    final nunito = GoogleFonts.nunitoTextTheme(base);
    return TextTheme(
      displayLarge: poppins.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium:
          poppins.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      displaySmall: poppins.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineLarge:
          poppins.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium:
          poppins.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall:
          poppins.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: poppins.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: poppins.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: poppins.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: nunito.bodyLarge,
      bodyMedium: nunito.bodyMedium,
      bodySmall: nunito.bodySmall,
      labelLarge: nunito.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: nunito.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      labelSmall: nunito.labelSmall?.copyWith(fontWeight: FontWeight.w700),
    ).apply(
      bodyColor: HomelyColors.ink,
      displayColor: HomelyColors.ink,
    );
  }
}

/// Reusable button styles that the [ThemeData] can't express as a single
/// default — chiefly the gold "appetite" CTA (Add, Place order, View cart)
/// which must stay distinct from the blue primary.
class HomelyStyles {
  HomelyStyles._();

  /// Turmeric-gold call-to-action for food/urgency actions.
  static ButtonStyle get accentButton => FilledButton.styleFrom(
        backgroundColor: HomelyColors.gold,
        foregroundColor: HomelyColors.ink,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
      );
}

/// Format a paise amount to a human-readable rupee string.
///
/// Money is stored in paise (integers) throughout the system.
/// This helper is the ONLY place paise should be converted to rupees for display.
///
/// Examples:
///   formatPaise(500)   -> '₹5'
///   formatPaise(1550)  -> '₹15.50'
///   formatPaise(20000) -> '₹200'
String formatPaise(int paise) {
  return '₹${(paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2)}';
}
