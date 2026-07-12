import 'package:flutter/material.dart';

/// Shared theme for both the Customer and Seller apps.
///
/// Uses Material 3 with a deep orange primary color to evoke a warm,
/// home-cooking feel.
class AppTheme {
  AppTheme._();

  static const Color _primaryColor = Colors.deepOrange;

  /// Light theme for the Homely apps.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
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
