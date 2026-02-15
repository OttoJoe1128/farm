import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Rol Secici Widget - Dropdown ile rol atama
class RolSecici extends StatelessWidget {
  final String currentRole;
  final ValueChanged<String> onRoleChanged;
  final bool isEnabled;

  const RolSecici({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
    this.isEnabled = true,
  });

  static const List<Map<String, dynamic>> _rolListesi = [
    {'value': 'admin', 'label': 'Admin', 'icon': Icons.admin_panel_settings, 'color': Colors.redAccent},
    {'value': 'yonetici', 'label': 'Yonetici', 'icon': Icons.manage_accounts, 'color': Colors.blueAccent},
    {'value': 'calisan', 'label': 'Calisan', 'icon': Icons.person, 'color': Colors.greenAccent},
    {'value': 'tarimci', 'label': 'Tarimci', 'icon': Icons.eco, 'color': Colors.amberAccent},
    {'value': 'izleyici', 'label': 'Izleyici', 'icon': Icons.visibility, 'color': Colors.grey},
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: currentRole,
      decoration: const InputDecoration(
        labelText: 'Rol',
        prefixIcon: Icon(Icons.shield_outlined),
      ),
      dropdownColor: AppColors.backgroundCard,
      items: _rolListesi.map((Map<String, dynamic> rol) {
        return DropdownMenuItem<String>(
          value: rol['value'] as String,
          child: Row(
            children: [
              Icon(
                rol['icon'] as IconData,
                size: 18,
                color: rol['color'] as Color,
              ),
              const SizedBox(width: 8),
              Text(rol['label'] as String),
            ],
          ),
        );
      }).toList(),
      onChanged: isEnabled
          ? (String? value) {
              if (value != null) {
                onRoleChanged(value);
              }
            }
          : null,
    );
  }
}
