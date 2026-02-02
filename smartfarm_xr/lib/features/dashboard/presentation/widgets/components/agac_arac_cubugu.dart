import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';

/// Ağaç Araç Çubuğu Widget'ı
/// Ağaç dikimi için araçlar
class AgacAracCubugu extends StatelessWidget {
  final bool clustersEnabled;
  final VoidCallback onToggleClusters;
  final VoidCallback onPlantGrid;
  final VoidCallback onPlantLine;
  final VoidCallback onPlantRandom;
  final VoidCallback onImport;
  final VoidCallback onClearTrees;

  const AgacAracCubugu({
    super.key,
    required this.clustersEnabled,
    required this.onToggleClusters,
    required this.onPlantGrid,
    required this.onPlantLine,
    required this.onPlantRandom,
    required this.onImport,
    required this.onClearTrees,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ağaç Dikim Araçları',
          style: AppTextStyles.headingSmall,
        ),
        SizedBox(height: AppSpacing.md),
        SwitchListTile(
          title: const Text('Kümeleme'),
          subtitle: const Text('Ağaçları grupla'),
          value: clustersEnabled,
          onChanged: (_) => onToggleClusters(),
          activeColor: AppColors.primary,
        ),
        SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _buildActionButton(
              icon: Icons.grid_4x4,
              label: 'Izgara Dikim',
              onTap: onPlantGrid,
              color: AppColors.primary,
            ),
            _buildActionButton(
              icon: Icons.straight,
              label: 'Şerit Dikim',
              onTap: onPlantLine,
              color: AppColors.secondary,
            ),
            _buildActionButton(
              icon: Icons.casino,
              label: 'Rastgele',
              onTap: onPlantRandom,
              color: AppColors.warning,
            ),
            _buildActionButton(
              icon: Icons.upload_file,
              label: 'İçe Aktar',
              onTap: onImport,
              color: AppColors.info,
            ),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Temizle',
              onTap: onClearTrees,
              color: AppColors.error,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.notrBeyaz,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
