import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_spacing.dart';

/// SmartFarm XR Uygulama Teması
/// Koyu tema (Dark Theme) kullanılarak oluşturulmuştur
class AppTheme {
  // Private constructor - singleton pattern
  AppTheme._();
  
  /// Ana tema verisi
  static ThemeData get darkTheme {
    return ThemeData(
      // Temel tema ayarları
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Renk şeması
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gridMor,
        secondary: AppColors.kartSu,
        surface: AppColors.backgroundCard,
        background: AppColors.backgroundPrimary,
        error: AppColors.error,
        onPrimary: AppColors.notrBeyaz,
        onSecondary: AppColors.notrBeyaz,
        onSurface: AppColors.notrBeyaz,
        onBackground: AppColors.notrBeyaz,
        onError: AppColors.notrBeyaz,
      ),
      
      // Scaffold arka plan rengi
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      
      // AppBar teması
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundSecondary,
        foregroundColor: AppColors.notrBeyaz,
        elevation: AppSpacing.elevationNone,
        centerTitle: true,
        titleTextStyle: AppTextStyles.headingMedium,
      ),
      
      // Card teması
      cardTheme: CardTheme(
        color: AppColors.backgroundCard,
        elevation: AppSpacing.elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        ),
        margin: EdgeInsets.all(AppSpacing.cardMargin),
      ),
      
      // Elevated Button teması
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gridMor,
          foregroundColor: AppColors.notrBeyaz,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPadding,
            vertical: AppSpacing.buttonPadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          ),
          textStyle: AppTextStyles.buttonMedium,
          elevation: AppSpacing.elevationLow,
        ),
      ),
      
      // Text Button teması
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.kartSu,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPadding,
            vertical: AppSpacing.buttonPadding,
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      
      // Outlined Button teması
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.notrBeyaz,
          side: const BorderSide(color: AppColors.gridMor),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPadding,
            vertical: AppSpacing.buttonPadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      
      // Icon Button teması
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.notrBeyaz,
          backgroundColor: AppColors.backgroundCard,
          padding: EdgeInsets.all(AppSpacing.buttonPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          ),
        ),
      ),
      
      // Input Decoration teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.notrGri600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.notrGri600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.gridMor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: EdgeInsets.all(AppSpacing.buttonPadding),
        labelStyle: AppTextStyles.bodyMedium,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.notrGri500,
        ),
      ),
      
      // Divider teması
      dividerTheme: const DividerThemeData(
        color: AppColors.notrGri700,
        thickness: 1,
        space: AppSpacing.md,
      ),
      
      // Chip teması
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        selectedColor: AppColors.gridMor,
        labelStyle: AppTextStyles.bodySmall,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
        ),
      ),
      
      // SnackBar teması
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundCard,
        contentTextStyle: AppTextStyles.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Dialog teması
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        ),
        titleTextStyle: AppTextStyles.headingMedium,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),
      
      // Bottom Sheet teması
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardBorderRadius),
          ),
        ),
      ),
    );
  }
  
  /// Açık tema (gelecekte kullanım için)
  static ThemeData get lightTheme {
    return darkTheme.copyWith(
      brightness: Brightness.light,
      // Açık tema renkleri burada tanımlanacak
    );
  }
}
