import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/themes/texttheme.dart';

class ApplicationTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.lightblue,
      onPrimary: AppColors.white,
      secondary: AppColors.primaryBlueSteel,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.darkblue,
      error: AppColors.red,
      onError: AppColors.white,
      outline: AppColors.border,
    ),
    scaffoldBackgroundColor: AppColors.pageScaffold,
    dividerColor: AppColors.lightWhite,
    textTheme: AppTextTheme.lightTextTheme,
    splashFactory: InkSplash.splashFactory,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        foregroundColor: AppColors.white,
        backgroundColor: AppColors.lightblue,
        disabledForegroundColor: AppColors.white.withValues(alpha: 0.86),
        disabledBackgroundColor: AppColors.primaryDisabledFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkblue,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
