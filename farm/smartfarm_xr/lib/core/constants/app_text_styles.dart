import 'package:flutter/material.dart';
import 'app_colors.dart';

/// SmartFarm XR Uygulama Metin Stilleri
/// Inter font ailesi kullanılarak oluşturulmuştur
class AppTextStyles {
  // Private constructor - singleton pattern
  AppTextStyles._();
  
  // FONT BOYUTLARI
  static const double size12 = 12.0;
  static const double size14 = 14.0;
  static const double size16 = 16.0;
  static const double size18 = 18.0;
  static const double size20 = 20.0;
  static const double size24 = 24.0;
  static const double size28 = 28.0;
  static const double size32 = 32.0;
  
  // FONT AĞIRLIKLARI
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;
  
  // SATIR YÜKSEKLİKLERİ
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.4;
  static const double lineHeightRelaxed = 1.6;
  
  // HARF ARALIKLARI
  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.5;
  
  // BAŞLIK STİLLERİ
  static const TextStyle h2 = TextStyle(
    fontFamily: 'Inter',
    fontSize: size24,
    fontWeight: weightBold,
    color: AppColors.notrSiyah,
    height: lineHeightTight,
  );
  
  static const TextStyle h3 = TextStyle(
    fontFamily: 'Inter',
    fontSize: size20,
    fontWeight: weightSemiBold,
    color: AppColors.notrSiyah,
    height: lineHeightTight,
  );
  
  // KART BAŞLIK VE DEĞER STİLLERİ
  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: size16,
    fontWeight: weightSemiBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle cardValue = TextStyle(
    fontFamily: 'Inter',
    fontSize: size24,
    fontWeight: weightBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  // UYARI KARTI STİLLERİ
  static const TextStyle alertTitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: size16,
    fontWeight: weightSemiBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle alertMessage = TextStyle(
    fontFamily: 'Inter',
    fontSize: size14,
    fontWeight: weightRegular,
    color: AppColors.notrGri300,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );
  
  // GENEL METİN STİLLERİ
  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: size12,
    fontWeight: weightRegular,
    color: AppColors.notrGri200,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: size14,
    fontWeight: weightRegular,
    color: AppColors.notrGri100,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: size16,
    fontWeight: weightRegular,
    color: AppColors.notrBeyaz,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );
  
  // BAŞLIK STİLLERİ
  static const TextStyle headingSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: size18,
    fontWeight: weightSemiBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: size20,
    fontWeight: weightSemiBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle headingLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: size24,
    fontWeight: weightBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle headingXLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: size28,
    fontWeight: weightBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  // BUTON STİLLERİ
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: size14,
    fontWeight: weightMedium,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: size16,
    fontWeight: weightMedium,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: size18,
    fontWeight: weightSemiBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
    // CAPTION STİLLERİ
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: size12,
    fontWeight: weightRegular,
    color: AppColors.notrGri400,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: 'Inter',
    fontSize: size12,
    fontWeight: weightMedium,
    color: AppColors.notrGri500,
    height: lineHeightTight,
    letterSpacing: letterSpacingWide,
  );
  
  // EK STİLLER
  static const TextStyle headline = TextStyle(
    fontFamily: 'Inter',
    fontSize: size24,
    fontWeight: weightBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle subtitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: size18,
    fontWeight: weightSemiBold,
    color: AppColors.notrBeyaz,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );
  
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: size14,
    fontWeight: weightRegular,
    color: AppColors.notrBeyaz,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );
}
