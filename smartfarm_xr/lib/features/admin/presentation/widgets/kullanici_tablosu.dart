import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Kullanici Tablosu Widget - DataTable ile kullanici listesi
class KullaniciTablosu extends StatelessWidget {
  final List<Map<String, dynamic>> kullanicilar;
  final Function(String userId, String newRole) onRolDegistir;
  final Function(String userId) onDeaktiveEt;
  final Function(String userId) onDetayGor;

  const KullaniciTablosu({
    super.key,
    required this.kullanicilar,
    required this.onRolDegistir,
    required this.onDeaktiveEt,
    required this.onDetayGor,
  });

  static const List<String> _roller = ['admin', 'yonetici', 'calisan', 'tarimci', 'izleyici'];

  @override
  Widget build(BuildContext context) {
    if (kullanicilar.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('Kullanici bulunamadi', style: TextStyle(color: AppColors.notrGri500)),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.backgroundSecondary),
        columns: const [
          DataColumn(label: Text('Kullanici', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('E-posta', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Rol', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Durum', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Kayit', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Islemler', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: kullanicilar.map((Map<String, dynamic> user) {
          final String userId = user['id'] as String? ?? '';
          final String username = user['username'] as String? ?? '';
          final String email = user['email'] as String? ?? '';
          final String role = user['role'] as String? ?? 'izleyici';
          final bool isActive = user['is_active'] as bool? ?? true;
          final String fullName = user['full_name'] as String? ?? username;
          final String createdAt = _formatDate(user['created_at'] as String?);
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _rolRengi(role).withValues(alpha: 0.3),
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 12, color: _rolRengi(role)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('@$username', style: const TextStyle(fontSize: 11, color: AppColors.notrGri500)),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(Text(email, style: const TextStyle(fontSize: 13))),
              DataCell(
                DropdownButton<String>(
                  value: role,
                  underline: const SizedBox(),
                  isDense: true,
                  dropdownColor: AppColors.backgroundCard,
                  items: _roller.map((String r) {
                    return DropdownMenuItem<String>(
                      value: r,
                      child: _buildRolBadge(r),
                    );
                  }).toList(),
                  onChanged: (String? newRole) {
                    if (newRole != null && newRole != role) {
                      onRolDegistir(userId, newRole);
                    }
                  },
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.success.withValues(alpha: 0.2)
                        : AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Aktif' : 'Pasif',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              DataCell(Text(createdAt, style: const TextStyle(fontSize: 12, color: AppColors.notrGri400))),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18),
                      tooltip: 'Detay',
                      onPressed: () => onDetayGor(userId),
                    ),
                    if (isActive)
                      IconButton(
                        icon: const Icon(Icons.person_off, size: 18, color: AppColors.error),
                        tooltip: 'Deaktive Et',
                        onPressed: () => onDeaktiveEt(userId),
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRolBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _rolRengi(role).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _rolAdi(role),
        style: TextStyle(fontSize: 12, color: _rolRengi(role), fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _rolRengi(String role) {
    switch (role) {
      case 'admin': return Colors.redAccent;
      case 'yonetici': return Colors.blueAccent;
      case 'calisan': return Colors.greenAccent;
      case 'tarimci': return Colors.amberAccent;
      default: return AppColors.notrGri500;
    }
  }

  String _rolAdi(String role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'yonetici': return 'Yonetici';
      case 'calisan': return 'Calisan';
      case 'tarimci': return 'Tarimci';
      default: return 'Izleyici';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final DateTime date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return '-';
    }
  }
}
