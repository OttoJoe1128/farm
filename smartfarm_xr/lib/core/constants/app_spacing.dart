/// SmartFarm XR Uygulama Spacing Sistemi
/// 4px base unit kullanılarak oluşturulmuştur
class AppSpacing {
  // Private constructor - singleton pattern
  AppSpacing._();
  
  // BASE UNIT
  static const double base = 4.0;
  
  // SPACING SCALE
  static const double xs = base;        // 4px
  static const double sm = base * 2;    // 8px
  static const double md = base * 3;    // 12px
  static const double lg = base * 4;    // 16px
  static const double xl = base * 5;    // 20px
  static const double xxl = base * 6;   // 24px
  static const double xxxl = base * 8;  // 32px
  static const double huge = base * 10; // 40px
  static const double massive = base * 12; // 48px
  static const double giant = base * 16;   // 64px
  static const double colossal = base * 20; // 80px
  static const double titanic = base * 24;  // 96px
  
  // COMPONENT SPACING
  static const double cardPadding = lg;      // 16px
  static const double cardMargin = md;       // 12px
  static const double cardBorderRadius = md; // 12px
  
  static const double buttonPadding = md;    // 12px
  static const double buttonMargin = sm;     // 8px
  static const double buttonBorderRadius = sm; // 8px
  
  static const double iconSize = huge;       // 40px
  static const double iconSizeExpanded = massive; // 48px
  static const double iconSpacing = sm;      // 8px
  
  // LAYOUT SPACING
  static const double panelPadding = lg;     // 16px
  static const double panelSpacing = md;     // 12px
  static const double sectionSpacing = xl;   // 20px
  
  // GRID SPACING
  static const double gridGutter = md;       // 12px
  static const double gridMargin = lg;       // 16px
  
  // ANIMATION DURATIONS
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 200);
  static const Duration animationSlow = Duration(milliseconds: 300);
  
  // ELEVATION
  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationHigh = 3.0;
  static const double elevationMax = 4.0;
  
  // ALIASES FOR BACKWARD COMPATIBILITY
  static const double small = sm;      // 8px
  static const double medium = md;     // 12px
  static const double large = lg;      // 16px
  static const double radius = cardBorderRadius; // 12px
}
