import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  // ── Brand Palette ──────────────────────────────────────────────────────────
  static const Color primary   = Color(0xFF7B4DFF); // Velvet Violet
  static const Color secondary = Color(0xFFFF5C8A); // Rose Fusion
  static const Color accent    = Color(0xFF52F1D9); // Electric Aqua

  // ── Background / Surface ───────────────────────────────────────────────────
  static const Color background = Color(0xFF111827); // Deep midnight
  static const Color surface    = Color(0xFF1F2937); // Card / sheet bg
  static const Color surface2   = Color(0xFF374151); // Input / chip bg

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textDark   = Color(0xFFF9FAFB); // Near-white
  static const Color textMedium = Color(0xFF9CA3AF); // Mid grey
  static const Color textLight  = Color(0xFF4B5563); // Dim grey

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success   = Color(0xFF34D399);
  static const Color error     = Color(0xFFF87171);
  static const Color superLike = Color(0xFF38BDF8); // sky blue

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0D1117), Color(0xFF111827), Color(0xFF1A1033)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get cardGradient => LinearGradient(
    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Theme ──────────────────────────────────────────────────────────────────
  static ThemeData get theme => darkTheme();

  static ThemeData darkTheme() => _buildTheme(AppColors.dark, Brightness.dark);

  static ThemeData lightTheme() => _buildTheme(AppColors.light, Brightness.light);

  static ThemeData _buildTheme(AppColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accent,
        onTertiary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.textDark,
        background: c.background,
        onBackground: c.textDark,
        surfaceVariant: c.surface2,
        onSurfaceVariant: c.textMedium,
      ),
      scaffoldBackgroundColor: c.background,
      fontFamily: 'SF Pro Display',
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        iconTheme: IconThemeData(color: c.textDark),
        titleTextStyle: TextStyle(
          color: c.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.surface2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.surface2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: TextStyle(color: c.textMedium),
        hintStyle: TextStyle(color: c.textLight),
        prefixIconColor: c.textMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: primary,
        unselectedItemColor: c.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface2,
        labelStyle: TextStyle(color: c.textDark),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.surface2, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface,
        contentTextStyle: TextStyle(color: c.textDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
