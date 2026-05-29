import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surface2;
  final Color textDark;
  final Color textMedium;
  final Color textLight;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.textDark,
    required this.textMedium,
    required this.textLight,
  });

  static const dark = AppColors(
    background: Color(0xFF111827),
    surface: Color(0xFF1F2937),
    surface2: Color(0xFF374151),
    textDark: Color(0xFFF9FAFB),
    textMedium: Color(0xFF9CA3AF),
    textLight: Color(0xFF4B5563),
  );

  static const light = AppColors(
    background: Color(0xFFF5F0FF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDE8FF),
    textDark: Color(0xFF111827),
    textMedium: Color(0xFF4B5563),
    textLight: Color(0xFF9CA3AF),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surface2,
    Color? textDark,
    Color? textMedium,
    Color? textLight,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      textDark: textDark ?? this.textDark,
      textMedium: textMedium ?? this.textMedium,
      textLight: textLight ?? this.textLight,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      textDark: Color.lerp(textDark, other.textDark, t)!,
      textMedium: Color.lerp(textMedium, other.textMedium, t)!,
      textLight: Color.lerp(textLight, other.textLight, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.of(this);
}
