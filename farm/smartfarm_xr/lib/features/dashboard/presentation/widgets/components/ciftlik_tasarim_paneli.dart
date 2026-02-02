import 'package:flutter/material.dart';
// import 'package:mapbox_gl/mapbox_gl.dart'; // Geçici olarak devre dışı - Dart 3.5 uyumluluk sorunu
import 'package:smartfarm_xr/core/utils/mapbox_types.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';
import 'ciftlik_models.dart';

/// Çiftlik Tasarım Paneli Widget'ı
/// Grid tabanlı çiftlik tasarım arayüzü
class CiftlikTasarimPaneli extends StatelessWidget {
  final List<LatLng> araziSinirlari;
  final LatLng? baslangicNoktasi;
  final List<Map<String, dynamic>>? geojsonParcels;
  final double? customCellSize;
  final double? customWidth;
  final double? customHeight;
  final bool useManualDimensions;
  final List<List<GridCell>>? initialGrid;

  const CiftlikTasarimPaneli({
    super.key,
    required this.araziSinirlari,
    this.baslangicNoktasi,
    this.geojsonParcels,
    this.customCellSize,
    this.customWidth,
    this.customHeight,
    this.useManualDimensions = false,
    this.initialGrid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundPrimary,
      child: Column(
        children: [
          // Üst bilgi çubuğu
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            color: AppColors.backgroundSecondary,
            child: Row(
              children: [
                Icon(Icons.agriculture, color: AppColors.primary),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Çiftlik Tasarımı',
                  style: AppTextStyles.headingMedium,
                ),
                const Spacer(),
                if (araziSinirlari.isNotEmpty)
                  Text(
                    'Arazi: ${araziSinirlari.length} nokta',
                    style: AppTextStyles.caption,
                  ),
                if (geojsonParcels != null && geojsonParcels!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: AppSpacing.md),
                    child: Text(
                      'GeoJSON: ${geojsonParcels!.length} parsel',
                      style: AppTextStyles.caption,
                    ),
                  ),
              ],
            ),
          ),
          // Grid canvas
          Expanded(
            child: Container(
              color: AppColors.backgroundCard,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.grid_on,
                      size: 64,
                      color: AppColors.notrGri600,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Grid Tasarım Arayüzü',
                      style: AppTextStyles.headingMedium,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Grid sistemi burada gösterilecek',
                      style: AppTextStyles.bodyMedium,
                    ),
                    if (initialGrid != null && initialGrid!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          '${initialGrid!.length} satır x ${initialGrid!.first.length} sütun',
                          style: AppTextStyles.caption,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
