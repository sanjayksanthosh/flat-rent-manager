import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryLight = Color(0xFF3949AB);
  static const Color accent = Color(0xFF00BFA5);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color border = Color(0xFFE5E7EB);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorSchemeSeed: primary,
    scaffoldBackgroundColor: surface,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border.withValues(alpha: 0.5)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: primary),
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: danger),
      ),
      prefixIconColor: textSecondary,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: primary.withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary);
        }
        return TextStyle(fontSize: 12, color: textSecondary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primary, size: 24);
        }
        return IconThemeData(color: textSecondary, size: 24);
      }),
    ),
    dividerTheme: DividerThemeData(color: border.withValues(alpha: 0.5), thickness: 1, space: 1),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: TextStyle(fontSize: 15, color: textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary),
    ),
  );

  static BoxDecoration statCard(Color color) => BoxDecoration(
    gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)]),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: color.withValues(alpha: 0.2)),
  );

  static BoxDecoration actionBtn(Color color) => BoxDecoration(
    gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)]),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: color.withValues(alpha: 0.25)),
  );

  static Widget statusChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  );
}
