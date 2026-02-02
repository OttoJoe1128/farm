import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';

/// İkon Bar Widget'ı
/// Harita üzerinde araç seçimi için ikon bar
class IkonBar extends StatelessWidget {
  final String? selectedTool;
  final Function(String?) onSelect;
  final bool showHaritaKontrolleri;
  final bool showKonumButonlari;
  final VoidCallback onToggleHaritaKontrolleri;
  final VoidCallback onToggleKonumButonlari;

  const IkonBar({
    super.key,
    required this.selectedTool,
    required this.onSelect,
    required this.showHaritaKontrolleri,
    required this.showKonumButonlari,
    required this.onToggleHaritaKontrolleri,
    required this.onToggleKonumButonlari,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.panelPadding,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIconButton(
            icon: Icons.map,
            tool: 'map',
            label: 'Harita',
          ),
          SizedBox(width: AppSpacing.sm),
          _buildIconButton(
            icon: Icons.park,
            tool: 'tree',
            label: 'Ağaç',
          ),
          SizedBox(width: AppSpacing.sm),
          _buildIconButton(
            icon: Icons.fence,
            tool: 'fence',
            label: 'Çit',
          ),
          SizedBox(width: AppSpacing.sm),
          _buildIconButton(
            icon: Icons.home,
            tool: 'barn',
            label: 'Bina',
          ),
          SizedBox(width: AppSpacing.sm),
          _buildIconButton(
            icon: Icons.sensors,
            tool: 'sensor',
            label: 'Sensör',
          ),
          SizedBox(width: AppSpacing.sm),
          _buildIconButton(
            icon: Icons.camera_alt,
            tool: 'camera',
            label: 'Kamera',
          ),
          SizedBox(width: AppSpacing.sm),
          _buildIconButton(
            icon: Icons.water_drop,
            tool: 'pump',
            label: 'Pompa',
          ),
          SizedBox(width: AppSpacing.lg),
          _buildToggleButton(
            icon: Icons.settings,
            isActive: showHaritaKontrolleri,
            onTap: onToggleHaritaKontrolleri,
            label: 'Kontroller',
          ),
          SizedBox(width: AppSpacing.sm),
          _buildToggleButton(
            icon: Icons.add_location,
            isActive: showKonumButonlari,
            onTap: onToggleKonumButonlari,
            label: 'Konum',
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tool,
    required String label,
  }) {
    final isSelected = selectedTool == tool;
    return Tooltip(
      message: label,
      child: Material(
        color: isSelected
            ? AppColors.gridMor
            : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
        child: InkWell(
          onTap: () => onSelect(isSelected ? null : tool),
          borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? AppColors.gridMor
                    : AppColors.notrGri600,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppColors.notrBeyaz
                  : AppColors.notrGri300,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String label,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: isActive
            ? AppColors.primary
            : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive
                    ? AppColors.primary
                    : AppColors.notrGri600,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? AppColors.notrBeyaz
                  : AppColors.notrGri300,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
