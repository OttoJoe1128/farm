import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/utils/local_storage_service.dart';
import 'package:smartfarm_xr/features/dashboard/presentation/pages/arazilerim_sayfasi.dart';
import 'widgets/sol_panel.dart';
import 'widgets/harita_paneli.dart';
import 'widgets/sag_panel.dart';

/// SmartFarm XR Ana Dashboard Sayfası
/// 3 sütunlu layout: Sol Panel + Harita + Sağ Panel
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final LocalStorageService _storage = const LocalStorageService();
  static const String _farmsKey = 'sf_farms';
  String? _currentFarmId;
  List<Map<String, dynamic>> _farms = [];

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    _farms = await _storage.readCollection(_farmsKey);
    if (_farms.isEmpty) {
      final def = {'id': 'default', 'name': 'Varsayılan Arazi'};
      _farms = [def];
      await _storage.writeCollection(_farmsKey, _farms);
    }
    _currentFarmId ??= _farms.first['id'] as String;
    setState(() {});
  }

  void _createFarm() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: const Text('Yeni Arazi Oluştur'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Arazi adı'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oluştur')),
          ],
        );
      },
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      final id = 'farm_${DateTime.now().millisecondsSinceEpoch}';
      _farms.add({'id': id, 'name': controller.text.trim()});
      await _storage.writeCollection(_farmsKey, _farms);
      setState(() => _currentFarmId = id);
    }
  }

  void _navigateToMyFarms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ArazilerimSayfasi(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SmartFarm XR'),
            const SizedBox(width: 16),
            _buildFarmSelector(),
          ],
        ),
        backgroundColor: AppColors.backgroundSecondary,
        foregroundColor: AppColors.notrBeyaz,
        elevation: AppSpacing.elevationNone,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.agriculture),
            tooltip: 'Arazilerim',
            onPressed: () => _navigateToMyFarms(),
          ),
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            tooltip: 'Yeni Arazi',
            onPressed: _createFarm,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: Row(
        children: [
          // SOL PANEL - Bilgi Kartları
          Container(
            width: 280, // Daha dar genişlik
            height: double.infinity,
            color: AppColors.backgroundSecondary,
            child: const SolPanel(),
          ),
          
          // ORTA PANEL - Harita
          Expanded(
            child: Container(
              height: double.infinity,
              color: AppColors.backgroundPrimary,
              child: const HaritaPaneli(),
            ),
          ),
          
          // SAĞ PANEL - Uyarı Kartları
          Container(
            width: 280, // Daha dar genişlik
            height: double.infinity,
            color: AppColors.backgroundSecondary,
            child: const SagPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: AppColors.gridMor.withOpacity(0.5), width: 1),
      ),
      child: DropdownButton<String>(
        value: _currentFarmId,
        dropdownColor: AppColors.backgroundCard,
        underline: Container(),
        style: TextStyle(color: AppColors.notrBeyaz, fontSize: 12),
        items: _farms
            .map((f) => DropdownMenuItem(
                  value: f['id'] as String,
                  child: Text(f['name'] as String),
                ))
            .toList(),
        onChanged: (v) => setState(() => _currentFarmId = v),
      ),
    );
  }
}
