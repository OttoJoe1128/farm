import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';
import 'mapbox_harita.dart';

/// Harita Kontrolleri Widget'ı
/// Harita stil, zoom ve katman kontrolleri
class HaritaKontrolleri extends StatelessWidget {
  final MapboxHaritaController controller;
  final Function(String?) onToolSelected;

  const HaritaKontrolleri({
    super.key,
    required this.controller,
    required this.onToolSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Harita Stili',
          style: AppTextStyles.headingSmall,
        ),
        SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _buildStyleButton('Koyu', 'mapbox://styles/mapbox/dark-v11'),
            _buildStyleButton('Açık', 'mapbox://styles/mapbox/light-v11'),
            _buildStyleButton('Uydu', 'mapbox://styles/mapbox/satellite-v9'),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Araçlar',
          style: AppTextStyles.headingSmall,
        ),
        SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _buildToolButton(Icons.park, 'Ağaç', 'tree'),
            _buildToolButton(Icons.fence, 'Çit', 'fence'),
            _buildToolButton(Icons.home, 'Bina', 'barn'),
            _buildToolButton(Icons.sensors, 'Sensör', 'sensor'),
            _buildToolButton(Icons.camera_alt, 'Kamera', 'camera'),
            _buildToolButton(Icons.water_drop, 'Pompa', 'pump'),
          ],
        ),
      ],
    );
  }

  Widget _buildStyleButton(String label, String style) {
    return ElevatedButton(
      onPressed: () => controller.setStyle(style),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.backgroundSecondary,
        foregroundColor: AppColors.notrBeyaz,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildToolButton(IconData icon, String label, String tool) {
    return OutlinedButton.icon(
      onPressed: () => onToolSelected(tool),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.notrBeyaz,
        side: BorderSide(color: AppColors.gridMor),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
