import 'package:flutter/material.dart';

/// SmartFarm XR Uygulama Renk Paleti
/// Görsel referans alınarak oluşturulmuş uyumlu renk sistemi
class AppColors {
  // Private constructor - singleton pattern
  AppColors._();
  
  // KART RENKLERİ (Sol Panel)
  static const Color kartToprak = Color(0xFF8B4513);
  static const Color kartToprakDark = Color(0xFF654321);
  static const Color kartSu = Color(0xFF0066CC);
  static const Color kartSuDark = Color(0xFF004499);
  static const Color kartEnerjiUretim = Color(0xFF00CC66);
  static const Color kartEnerjiUretimDark = Color(0xFF00994D);
  static const Color kartEnerjiTuketim = Color(0xFFFF6600);
  static const Color kartEnerjiTuketimDark = Color(0xFFCC5200);
  static const Color kartHava = Color(0xFF9933CC);
  static const Color kartHavaDark = Color(0xFF772299);
  
  // UYARI RENKLERİ (Sağ Panel)
  static const Color uyariNemKritik = Color(0xFFFF4444);
  static const Color uyariNemKritikDark = Color(0xFFCC3333);
  static const Color uyariSuDeposu = Color(0xFFFF8800);
  static const Color uyariSuDeposuDark = Color(0xFFCC6600);
  static const Color uyariEnerjiAzalma = Color(0xFFFFCC00);
  static const Color uyariEnerjiAzalmaDark = Color(0xFFCC9900);
  static const Color uyariGubreZamani = Color(0xFF66CC66);
  static const Color uyariGubreZamaniDark = Color(0xFF4D994D);
  static const Color uyariHayvanBesleme = Color(0xFFCC6699);
  static const Color uyariHayvanBeslemeDark = Color(0xFF994D73);
  
  // GRID RENKLERİ (Harita)
  static const Color gridMor = Color(0xFF9933CC);
  static const Color gridMorDark = Color(0xFF772299);
  
  // NÖTR RENKLER
  static const Color notrBeyaz = Color(0xFFFFFFFF);
  static const Color notrGri100 = Color(0xFFF5F5F5);
  static const Color notrGri200 = Color(0xFFEEEEEE);
  static const Color notrGri300 = Color(0xFFE0E0E0);
  static const Color notrGri400 = Color(0xFFBDBDBD);
  static const Color notrGri500 = Color(0xFF9E9E9E);
  static const Color notrGri600 = Color(0xFF757575);
  static const Color notrGri700 = Color(0xFF616161);
  static const Color notrGri800 = Color(0xFF424242);
  static const Color notrGri900 = Color(0xFF212121);
  static const Color notrSiyah = Color(0xFF000000);
  
  // SEMANTIC RENKLER
  static const Color primary = Color(0xFF00D4AA);
  static const Color primaryLight = Color(0xFF33DDBB);
  static const Color primaryDark = Color(0xFF00B894);
  static const Color secondary = Color(0xFF2196F3);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFBFE);
  static const Color textSecondary = Color(0xFF757575);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // ARKA PLAN RENKLERİ
  static const Color backgroundPrimary = Color(0xFF0A0A0A);
  static const Color backgroundSecondary = Color(0xFF1A1A1A);
  static const Color backgroundCard = Color(0xFF2A2A2A);
  
  // GÖLGE RENKLERİ
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x4D000000);
  
  // MATERIAL DESIGN 3 RENKLERİ
  static const Color surfaceVariant = Color(0xFFF3F1F1);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
}
