import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/features/dashboard/presentation/pages/ciftlik_tasarim_sayfasi.dart';

/// Arazilerim Sayfası - Kullanıcının kayıtlı çiftlik tasarımlarını listeler
class ArazilerimSayfasi extends StatefulWidget {
  const ArazilerimSayfasi({super.key});

  @override
  State<ArazilerimSayfasi> createState() => _ArazilerimSayfasiState();
}

class _ArazilerimSayfasiState extends State<ArazilerimSayfasi> {
  List<Map<String, dynamic>> _designs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDesigns();
  }

  Future<void> _loadDesigns() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/api/getFarmDesigns?user_token=user_123'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          setState(() {
            _designs = List<Map<String, dynamic>>.from(result['designs']);
            _isLoading = false;
          });
          print('✅ ${_designs.length} tasarım yüklendi');
        } else {
          setState(() {
            _error = result['error'] ?? 'Bilinmeyen hata';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Sunucu hatası: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Bağlantı hatası: $e';
        _isLoading = false;
      });
      print('❌ Tasarım yükleme hatası: $e');
    }
  }

  Future<void> _deleteDesign(int designId, String designName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: AppSpacing.small),
            Text('Tasarımı Sil'),
          ],
        ),
        content: Text('"$designName" tasarımını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:5000/api/deleteFarmDesign'),
        headers: {
          'Content-Type': 'application/json',
          'User-Token': 'user_123',
        },
        body: json.encode({
          'design_id': designId,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ "$designName" tasarımı silindi'),
              backgroundColor: Colors.green,
            ),
          );
          _loadDesigns(); // Listeyi yenile
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Silme işlemi başarısız'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _loadDesign(int designId) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/loadFarmDesign'),
        headers: {
          'Content-Type': 'application/json',
          'User-Token': 'user_123',
        },
        body: json.encode({
          'design_id': designId,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final design = result['design'];
          
          // Çiftlik tasarım sayfasına git
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CiftlikTasarimSayfasi(
                initialDesign: design,
                geojsonParcels: List<Map<String, dynamic>>.from(
                  design['geojson_parcels'] ?? []
                ), // GeoJSON parsellerini aktar
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Tasarım yüklenemedi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.agriculture, color: AppColors.primary),
            const SizedBox(width: AppSpacing.small),
            Text('Arazilerim', style: AppTextStyles.h2),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadDesigns,
            icon: Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.medium),
            Text('Tasarımlar yükleniyor...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: AppSpacing.medium),
            Text(
              'Hata: $_error',
              style: AppTextStyles.body.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.medium),
            ElevatedButton(
              onPressed: _loadDesigns,
              child: Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_designs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture, size: 64, color: AppColors.primary),
            const SizedBox(height: AppSpacing.medium),
            Text(
              'Henüz kayıtlı tasarımınız yok',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              'Yeni bir çiftlik tasarımı oluşturmak için\nharita sayfasına gidin',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.large),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.add),
              label: Text('Yeni Tasarım Oluştur'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDesigns,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.medium),
        itemCount: _designs.length,
        itemBuilder: (context, index) {
          final design = _designs[index];
          return _buildDesignCard(design);
        },
      ),
    );
  }

  Widget _buildDesignCard(Map<String, dynamic> design) {
    final designName = design['design_name'] ?? 'İsimsiz Tasarım';
    final createdAt = design['created_at'] ?? '';
    final updatedAt = design['updated_at'] ?? '';
    final designData = design['design_data'] ?? {};
    final geojsonParcels = design['geojson_parcels'] ?? [];
    
    // Tasarım istatistikleri
    final grid = designData['grid'] ?? [];
    final totalCells = grid.isNotEmpty ? grid.length * (grid.first?.length ?? 0) : 0;
    final occupiedCells = grid.fold(0, (sum, row) => 
      sum + (row as List).where((cell) => cell['isEmpty'] == false).length);
    final cellSize = designData['cellSize'] ?? 1.0;
    final araziGenislik = designData['araziGenislik'] ?? 0.0;
    final araziUzunluk = designData['araziUzunluk'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _loadDesign(design['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve tarih
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          designName,
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Oluşturulma: ${_formatDate(createdAt)}',
                          style: AppTextStyles.caption,
                        ),
                        if (updatedAt != createdAt)
                          Text(
                            'Güncelleme: ${_formatDate(updatedAt)}',
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteDesign(design['id'], designName);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Sil'),
                          ],
                        ),
                      ),
                    ],
                    child: Icon(Icons.more_vert, color: AppColors.textSecondary),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSpacing.medium),
              
              // İstatistikler
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.grid_on,
                      'Grid',
                      '${totalCells} hücre',
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.crop_square,
                      'Dolu',
                      '$occupiedCells hücre',
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.straighten,
                      'Boyut',
                      '${araziGenislik.toStringAsFixed(1)}x${araziUzunluk.toStringAsFixed(1)}m',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSpacing.medium),
              
              // GeoJSON bilgisi
              if (geojsonParcels.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.small),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'TKGM verisi mevcut (${geojsonParcels.length} parsel)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: AppSpacing.small),
              
              // Açıklama
              Text(
                'Tıklayarak tasarımı açın',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption,
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
