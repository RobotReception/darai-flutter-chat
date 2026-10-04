import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF1B5091);
  static const primaryLight = Color(0xFF3069AB);
  static const primaryContainer = Color(0xFFEAF1FA);
  static const secondary = Color(0xFF138577);
  static const success = Color(0xFF2E8B68);
  static const successLight = Color(0xFFE5F6EE);
  static const warning = Color(0xFFD98A28);
  static const warningLight = Color(0xFFFDF2E2);
  static const error = Color(0xFFC94F4F);
  static const backgroundLight = Color(0xFFF7F9F7);
  static const borderSubtle = Color(0xFFECEFEF);
  static const textPrimary = Color(0xFF172529);
  static const textSecondary = Color(0xFF5E7175);
  static const textMuted = Color(0xFF8E9FA2);
  static const textWhiteSecondary = Color(0xFFD4E1E3);
}

class AppTypography {
  AppTypography._();

  static TextStyle titleLarge({Color color = AppColors.textPrimary}) =>
      TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.35,
      );

  static TextStyle titleMedium({Color color = AppColors.textPrimary}) =>
      TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      );

  static TextStyle bodyLarge({Color color = AppColors.textPrimary}) =>
      TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.5,
      );

  static TextStyle bodyMedium({Color color = AppColors.textSecondary}) =>
      TextStyle(fontSize: 13, color: color, height: 1.5);

  static TextStyle bodySmall({Color color = AppColors.textMuted}) =>
      TextStyle(fontSize: 11.5, color: color, height: 1.4);
}

/// Darai palette. Fonts are supplied by the host application, not bundled here.
class DaraiChatTheme {
  DaraiChatTheme._();
  static ThemeData light({
    Color primary = AppColors.primary,
    String? fontFamily,
  }) => ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      primaryContainer: AppColors.primaryContainer,
      surface: AppColors.backgroundLight,
    ),
  );
}
