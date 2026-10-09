import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF182D2A);
  static const lime = Color(0xFFD9F3A3);
  static const seed = Color(0xFF326A59);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
      primary: dark ? const Color(0xFFAED5BC) : seed,
      onPrimary: dark ? ink : Colors.white,
      surface: dark ? const Color(0xFF141C1A) : const Color(0xFFF6F7F2),
      onSurface: dark ? const Color(0xFFE7ECE5) : const Color(0xFF20332E),
      surfaceContainerLow: dark ? const Color(0xFF1C2723) : Colors.white,
      surfaceContainerHighest: dark ? const Color(0xFF293730) : const Color(0xFFE8EEE6),
      outlineVariant: dark ? const Color(0xFF38483E) : const Color(0xFFDFE5DC),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final text = base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.3,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: scheme.onSurface),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface),
      bodySmall: TextStyle(fontSize: 12, height: 1.25, color: scheme.onSurfaceVariant),
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: dark ? const Color(0xFF364C3E) : const Color(0xFFE1EDD9),
        height: 72,
        labelTextStyle: WidgetStateProperty.all(TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFFDBE8DC) : ink,
        contentTextStyle: TextStyle(color: dark ? ink : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        dividerColor: scheme.outlineVariant,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);
}
