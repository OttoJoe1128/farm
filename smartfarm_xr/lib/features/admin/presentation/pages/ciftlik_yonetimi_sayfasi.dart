import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/admin_service.dart';

/// Ciftlik Yonetimi Sayfasi
class CiftlikYonetimiSayfasi extends StatefulWidget {
  const CiftlikYonetimiSayfasi({super.key});

  @override
  State<CiftlikYonetimiSayfasi> createState() => _CiftlikYonetimiSayfasiState();
}

class _CiftlikYonetimiSayfasiState extends State<CiftlikYonetimiSayfasi> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _ciftlikler = [];
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final Map<String, dynamic> response = await _adminService.fetchFarms();
      final List<dynamic> farms = response['farms'] as List<dynamic>? ?? [];
      setState(() {
        _ciftlikler = farms.cast<Map<String, dynamic>>();
        _yukleniyor = false;
      });
    } catch (err) {
      setState(() {
        _hata = 'Ciftlikler yuklenirken hata: $err';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _uyeleriGoster(String farmId, String farmName) async {
    try {
      final Map<String, dynamic> response = await _adminService.fetchFarmMembers(farmId);
      final List<dynamic> members = response['members'] as List<dynamic>? ?? [];
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('$farmName - Uyeler'),
          content: SizedBox(
            width: 400,
            child: members.isEmpty
                ? const Text('Uye bulunamadi')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: members.map((dynamic m) {
                      final Map<String, dynamic> member = m as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          child: Text(
                            ((member['full_name'] as String?) ?? (member['username'] as String?) ?? '?')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(member['full_name'] as String? ?? member['username'] as String? ?? '-'),
                        subtitle: Text(member['email'] as String? ?? '-'),
                        trailing: _buildRolChip(member['role'] as String? ?? 'izleyici'),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          ],
        ),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uyeler yuklenemedi: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRolChip(String role) {
    Color chipColor;
    switch (role) {
      case 'admin': chipColor = Colors.redAccent; break;
      case 'yonetici': chipColor = Colors.blueAccent; break;
      case 'calisan': chipColor = Colors.greenAccent; break;
      case 'tarimci': chipColor = Colors.amberAccent; break;
      default: chipColor = AppColors.notrGri500;
    }
    return Chip(
      label: Text(role, style: TextStyle(fontSize: 11, color: chipColor)),
      backgroundColor: chipColor.withValues(alpha: 0.15),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ciftlik Yonetimi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_ciftlikler.length} ciftlik',
                style: const TextStyle(color: AppColors.notrGri500),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
                onPressed: _verileriYukle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _hata != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text(_hata!, style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _verileriYukle, child: const Text('Tekrar Dene')),
                          ],
                        ),
                      )
                    : _ciftlikler.isEmpty
                        ? const Center(child: Text('Henuz ciftlik bulunamadi', style: TextStyle(color: AppColors.notrGri500)))
                        : ListView.builder(
                            itemCount: _ciftlikler.length,
                            itemBuilder: (BuildContext context, int index) {
                              final Map<String, dynamic> farm = _ciftlikler[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.kartEnerjiUretim.withValues(alpha: 0.2),
                                    child: const Icon(Icons.agriculture, color: AppColors.kartEnerjiUretim),
                                  ),
                                  title: Text(
                                    farm['name'] as String? ?? '-',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (farm['description'] != null)
                                        Text(
                                          farm['description'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (farm['area_hectares'] != null)
                                            Text(
                                              '${farm['area_hectares']} ha',
                                              style: const TextStyle(fontSize: 11, color: AppColors.notrGri500),
                                            ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (farm['is_active'] as bool? ?? true)
                                                  ? AppColors.success.withValues(alpha: 0.2)
                                                  : AppColors.error.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              (farm['is_active'] as bool? ?? true) ? 'Aktif' : 'Pasif',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: (farm['is_active'] as bool? ?? true) ? AppColors.success : AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.group, size: 20),
                                    tooltip: 'Uyeleri Gor',
                                    onPressed: () => _uyeleriGoster(
                                      farm['id'] as String,
                                      farm['name'] as String? ?? 'Ciftlik',
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
