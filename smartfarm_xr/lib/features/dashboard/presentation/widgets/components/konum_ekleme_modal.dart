import 'package:flutter/material.dart';
// import 'package:mapbox_gl/mapbox_gl.dart'; // Geçici olarak devre dışı - Dart 3.5 uyumluluk sorunu
import 'package:smartfarm_xr/core/utils/mapbox_types.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';

/// Konum Ekleme Modal Widget'ı
/// Haritaya yeni konum eklemek için modal
class KonumEklemeModal extends StatefulWidget {
  final LatLng position;
  final Function(LatLng position, String type, String label) onLocationAdded;

  const KonumEklemeModal({
    super.key,
    required this.position,
    required this.onLocationAdded,
  });

  @override
  State<KonumEklemeModal> createState() => _KonumEklemeModalState();
}

class _KonumEklemeModalState extends State<KonumEklemeModal> {
  final TextEditingController _labelController = TextEditingController();
  String _selectedType = 'tree';

  final List<Map<String, dynamic>> _locationTypes = [
    {'value': 'tree', 'label': 'Ağaç', 'icon': Icons.park},
    {'value': 'barn', 'label': 'Bina', 'icon': Icons.home},
    {'value': 'sensor', 'label': 'Sensör', 'icon': Icons.sensors},
    {'value': 'camera', 'label': 'Kamera', 'icon': Icons.camera_alt},
    {'value': 'pump', 'label': 'Pompa', 'icon': Icons.water_drop},
  ];

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundCard,
      title: Row(
        children: [
          Icon(Icons.add_location_alt, color: AppColors.primary),
          SizedBox(width: AppSpacing.sm),
          const Text('Yeni Konum Ekle'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konum: ${widget.position.latitude.toStringAsFixed(6)}, ${widget.position.longitude.toStringAsFixed(6)}',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Tür',
            style: AppTextStyles.bodyMedium,
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _locationTypes.map((type) {
              final isSelected = _selectedType == type['value'];
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type['icon'] as IconData, size: 16),
                    SizedBox(width: AppSpacing.xs),
                    Text(type['label'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedType = type['value'] as String);
                  }
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.notrBeyaz : AppColors.notrGri300,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: AppSpacing.md),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'Etiket (Opsiyonel)',
              hintText: 'Örn: Ana Bina, Sensör 1',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            final label = _labelController.text.trim().isEmpty
                ? _locationTypes.firstWhere((t) => t['value'] == _selectedType)['label'] as String
                : _labelController.text.trim();
            widget.onLocationAdded(widget.position, _selectedType, label);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
