import 'package:flutter/material.dart';
// import 'package:mapbox_gl/mapbox_gl.dart'; // Geçici olarak devre dışı - Dart 3.5 uyumluluk sorunu
import 'package:smartfarm_xr/core/utils/mapbox_types.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';
import 'package:smartfarm_xr/core/services/konum_servisi.dart';
import 'components/mapbox_harita.dart';
import 'components/harita_kontrolleri.dart';
import 'components/ikon_bar.dart';
import 'components/agac_arac_cubugu.dart';
import 'components/konum_ekleme_modal.dart';
// Konum navigatörü kaldırıldı
import 'components/draggable_panel.dart';
import '../pages/ciftlik_tasarim_sayfasi.dart';

/// Harita Paneli - Orta Panel
/// Grid arka plan + Mapbox entegrasyonu için hazır
class HaritaPaneli extends StatefulWidget {
  const HaritaPaneli({super.key});

  @override
  State<HaritaPaneli> createState() => _HaritaPaneliState();
}

class _HaritaPaneliState extends State<HaritaPaneli> {
  final MapboxHaritaController _mapboxController = MapboxHaritaController();
  String? _selectedTool; // 'tree','fence','barn','sensor','camera','pump'
  bool _treeClusters = true;
  // Konum navigatörü kaldırıldı - otomatik konum gösterimi
  LatLng? _currentLocation; // Güncel konum
  
  @override
  void initState() {
    super.initState();
    // Konum servisi Linux'ta çalışmıyor, geçici olarak devre dışı
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _startLocationService();
    // });
  }
  
  // Draggable panel durumları
  bool _showHaritaKontrolleri = true;
  // Konum navigatörü kaldırıldı - otomatik konum gösterimi
  bool _showKonumEkleme = false;
  bool _showKonumButonlari = true; // Konum Araçları paneli varsayılan olarak görünür
  // Çiftlik tasarım paneli ayrı sayfaya taşındı
  bool _ciftlikTasarimSayfasiAcik = false;
  bool _parselSecimiModu = false; // GeoJSON parsel seçimi modu

  // Harita kontrol callback'leri
  void _onStyleChanged(String style) {
    _mapboxController.setStyle(style);
  }

  void _onZoomChanged(double zoom) {}

  void _onLayerToggled(String layer) {
    if (layer == 'devices') {
      _mapboxController.toggleDevices(true);
    }
  }

  void _onFullscreenToggle() {}

  void _onToolSelected(String? tool) => setState(() => _selectedTool = tool);
  
  // Çit modu kapatıldığında çağrılacak callback
  void _onFenceModeDisabled() {
    setState(() {
      _selectedTool = null; // Çit modunu kapat
    });
  }

  // Çiftlik tasarım sayfasını aç
  void _onCiftlikTasarimKapat() {
    // Artık kullanılmıyor - sayfa olarak açılıyor
  }

  // Haritaya çift tık ile çiftlik tasarım paneli açma isteği
  void _onFarmDesignRequest(LatLng point) {
    // Eğer çiftlik tasarım sayfası zaten açıksa, yeni sayfa açma
    if (_ciftlikTasarimSayfasiAcik) {
      print('🚫 Çiftlik tasarım sayfası zaten açık, yeni sayfa açılmıyor');
      return;
    }
    
    print('🎯 Çiftlik tasarım paneli açılıyor - çit kontrolü kaldırıldı!');
    
    // Flag'i set et
    _ciftlikTasarimSayfasiAcik = true;
    
    // GeoJSON parsellerini al
    List<Map<String, dynamic>> geojsonParcels = [];
    if (_mapboxController.hasGeoJSONParcels()) {
      geojsonParcels = _mapboxController.getGeoJSONParcels();
      print('🎯 ${geojsonParcels.length} GeoJSON parseli tasarım paneline aktarılıyor');
    }
    
    // Çiftlik tasarım sayfasını aç
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CiftlikTasarimSayfasi(
          araziSinirlari: const [], // Çit sistemi kaldırıldı - boş liste
          baslangicNoktasi: point,
          geojsonParcels: geojsonParcels, // GeoJSON parseller
        ),
      ),
    ).then((_) {
      // Sayfa kapandığında flag'i sıfırla
      _ciftlikTasarimSayfasiAcik = false;
      print('🎯 Çiftlik tasarım sayfası kapandı, flag sıfırlandı');
    });
    
    // Kullanıcıya bilgi ver
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 Çiftlik tasarım sayfası açıldı! Çift tık ile açıldı: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Konum ekleme butonları
  Widget _buildLocationButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.notrGri600.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLocationButton(
            icon: Icons.add_location_alt,
            label: 'Konum Ekle',
            color: AppColors.primary,
            onTap: _showLocationModal,
          ),
          const SizedBox(height: 8),
          _buildLocationButton(
            icon: Icons.park,
            label: 'Ağaç Ekle',
            color: Colors.green,
            onTap: () => _addLocationAtCenter('tree'),
          ),
          const SizedBox(height: 8),
          _buildLocationButton(
            icon: Icons.home,
            label: 'Bina Ekle',
            color: Colors.orange,
            onTap: () => _addLocationAtCenter('barn'),
          ),
          const SizedBox(height: 8),
          _buildLocationButton(
            icon: Icons.sensors,
            label: 'Sensör Ekle',
            color: Colors.blue,
            onTap: () => _addLocationAtCenter('sensor'),
          ),
          const SizedBox(height: 8),
          _buildLocationButton(
            icon: Icons.agriculture,
            label: 'Çiftlik Tasarımı',
            color: Colors.purple,
            onTap: _showCiftlikTasarimPanel,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Text(
              '💡 Önce çit çizin, sonra buraya tıklayın!',
              style: TextStyle(
                color: Colors.purple,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Konum ekleme modal'ını göster
  void _showLocationModal() {
    // Haritanın merkez konumunu al
    final centerPosition = LatLng(39.9334, 32.8597); // Ankara koordinatları (varsayılan)
    
    showDialog(
      context: context,
      builder: (context) => KonumEklemeModal(
        position: centerPosition,
        onLocationAdded: _onLocationAdded,
      ),
    );
  }

  // Çiftlik tasarım panelini göster
  void _showCiftlikTasarimPanel() {
    // Eğer çiftlik tasarım sayfası zaten açıksa, yeni sayfa açma
    if (_ciftlikTasarimSayfasiAcik) {
      print('🚫 Çiftlik tasarım sayfası zaten açık, yeni sayfa açılmıyor');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Çiftlik tasarım sayfası zaten açık!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Çit noktalarından arazi sınırlarını al
    final araziSinirlari = _mapboxController.getFencePoints();
    
    // Debug bilgisi ekle
    print('🔍 Debug: Çit noktaları sayısı: ${araziSinirlari.length}');
    if (araziSinirlari.isNotEmpty) {
      print('🔍 Debug: İlk nokta: ${araziSinirlari.first.latitude}, ${araziSinirlari.first.longitude}');
      print('🔍 Debug: Son nokta: ${araziSinirlari.last.latitude}, ${araziSinirlari.last.longitude}');
    }
    
    if (araziSinirlari.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Önce arazi sınırlarını çit ile belirleyin! (Debug: ${_mapboxController.fencePoints.length} aktif, ${_mapboxController.getFencePoints().length} toplam)'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    
    // Flag'i set et
    _ciftlikTasarimSayfasiAcik = true;
    
    // Çiftlik tasarım sayfasını aç
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CiftlikTasarimSayfasi(
          araziSinirlari: araziSinirlari,
          baslangicNoktasi: araziSinirlari.isNotEmpty ? araziSinirlari.first : null,
        ),
      ),
    ).then((_) {
      // Sayfa kapandığında flag'i sıfırla
      _ciftlikTasarimSayfasiAcik = false;
      print('🎯 Çiftlik tasarım sayfası kapandı, flag sıfırlandı');
    });
    
    // Kullanıcıya bilgi ver
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 Çiftlik tasarım sayfası açıldı! Arazi: ${araziSinirlari.length} nokta'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Merkeze konum ekle
  void _addLocationAtCenter(String type) {
    final centerPosition = LatLng(39.9334, 32.8597); // Ankara koordinatları (varsayılan)
    final label = _getDefaultLabel(type);
    
    switch (type) {
      case 'tree':
        _mapboxController.addTree(centerPosition, label);
        break;
      case 'barn':
        _mapboxController.addBuilding(centerPosition, label);
        break;
      case 'sensor':
        _mapboxController.addSensor(centerPosition, label);
        break;
    }
  }

  // Varsayılan etiket oluştur
  String _getDefaultLabel(String type) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    switch (type) {
      case 'tree':
        return 'Ağaç $timestamp';
      case 'barn':
        return 'Bina $timestamp';
      case 'sensor':
        return 'Sensör $timestamp';
      default:
        return 'Konum $timestamp';
    }
  }

  // Konum eklendiğinde callback
  void _onLocationAdded(LatLng position, String type, String label) {
    switch (type) {
      case 'tree':
        _mapboxController.addTree(position, label);
        break;
      case 'barn':
        _mapboxController.addBuilding(position, label);
        break;
      case 'sensor':
        _mapboxController.addSensor(position, label);
        break;
      case 'camera':
        _mapboxController.addCamera(position, label);
        break;
      case 'pump':
        _mapboxController.addPump(position, label);
        break;
    }
  }

  // Konum bulunduğunda callback
  void _onLocationFound(LatLng position) {
    // Güncel konumu güncelle
    setState(() {
      _currentLocation = position;
    });
    
    // Haritada konumu göster
    _mapboxController.showLocation(position);
    
    debugPrint('Konum bulundu: ${position.latitude}, ${position.longitude}');
  }

  // Konum servisini otomatik başlat
  void _startLocationService() async {
    try {
      final position = await KonumServisi.instance.getCurrentLocation();
      if (position != null) {
        _onLocationFound(position);
        
        // Kullanıcıya bilgi ver
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Konum otomatik olarak alındı ve haritada gösterildi'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
    }
  }

  // Konum navigatörü kaldırıldı - otomatik konum gösterimi

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
        // Grid Arka Plan
        _buildGridBackground(),
        
        // DragTarget ile sarılmış harita içerği
        Center(
          child: DragTarget<String>(
            builder: (context, candidateData, rejectedData) {
              return _buildMapContent();
            },
            onWillAccept: (data) => data != null,
            onAcceptWithDetails: (details) {
              final String tool = details.data;
              _mapboxController.addByScreenOffset(tool, details.offset);
            },
          ),
        ),
        
        // İkon bar
        Positioned(
          top: AppSpacing.panelPadding,
          left: 0,
          right: 0,
          child: IkonBar(
            selectedTool: _selectedTool,
            onSelect: _onToolSelected,
            showHaritaKontrolleri: _showHaritaKontrolleri,
            showKonumButonlari: _showKonumButonlari,
            onToggleHaritaKontrolleri: () => setState(() => _showHaritaKontrolleri = !_showHaritaKontrolleri),
            onToggleKonumButonlari: () => setState(() => _showKonumButonlari = !_showKonumButonlari),
          ),
        ),
        
        // Draggable Paneller
        if (_showHaritaKontrolleri)
          DraggablePanel(
            title: 'Harita Kontrolleri',
            initialPosition: const Offset(20, 100),
            width: 280,
            onClose: () => setState(() => _showHaritaKontrolleri = false),
            child: HaritaKontrolleri(
              controller: _mapboxController,
              onToolSelected: _onToolSelected,
            ),
          ),
        
        // Konum Navigatörü Panel kaldırıldı - otomatik konum gösterimi
        
        if (_showKonumButonlari)
          DraggablePanel(
            title: 'Konum Araçları',
            initialPosition: const Offset(20, 200), // Daha yukarı taşındı
            width: 200,
            onClose: () => setState(() => _showKonumButonlari = false),
            child: _buildLocationButtons(),
          ),
        
        // Ağaç Araç Çubuğu - Draggable Panel
        if (_selectedTool == 'tree')
          DraggablePanel(
            title: 'Ağaç Araçları',
            initialPosition: const Offset(400, 100),
            width: 600,
            onClose: () => setState(() => _selectedTool = null),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Arazi Durumu Göstergesi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _mapboxController.hasActiveArea
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _mapboxController.hasActiveArea
                        ? Colors.green
                        : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _mapboxController.hasActiveArea
                          ? Icons.check_circle
                          : Icons.warning,
                        color: _mapboxController.hasActiveArea
                          ? Colors.green
                          : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mapboxController.hasActiveArea
                            ? '✅ Arazi sınırları tanımlanmış (${_mapboxController.fencePoints.length} nokta)'
                            : '⚠️ Arazi sınırları tanımlanmamış! Önce çit ikonuna tıklayıp arazi sınırlarını çizin.',
                          style: TextStyle(
                            color: _mapboxController.hasActiveArea
                              ? Colors.green
                              : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Ağaç Araçları
                AgacAracCubugu(
                  clustersEnabled: _treeClusters,
                  onToggleClusters: () {
                    setState(() => _treeClusters = !_treeClusters);
                    _mapboxController.setTreeClustering(_treeClusters);
                  },
                  onPlantGrid: _askGridParams,
                  onPlantLine: _askLineSpacing,
                  onPlantRandom: _askRandomCount,
                  onImport: () async { await _mapboxController.importTrees(); },
                  onClearTrees: () async { await _mapboxController.clearTrees(); },
                ),
              ],
            ),
          ),
        
        // Çiftlik Tasarım Paneli ayrı sayfaya taşındı

      ],
      ),
    );
  }

  Future<void> _askGridParams() async {
    final rowsCtl = TextEditingController(text: '5');
    final colsCtl = TextEditingController(text: '5');
    final spacingCtl = TextEditingController(text: '50');
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Row(
          children: [
            Icon(Icons.grid_4x4, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Izgara Dikim Ayarları'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rowsCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Satır Sayısı',
                hintText: 'Örn: 5',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: colsCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sütun Sayısı',
                hintText: 'Örn: 5',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: spacingCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ağaç Arası Mesafe (metre)',
                hintText: 'Örn: 50',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    
    if (ok == true) {
      final rows = int.tryParse(rowsCtl.text) ?? 5;
      final cols = int.tryParse(colsCtl.text) ?? 5;
      final spacing = double.tryParse(spacingCtl.text) ?? 50.0;
      
      // Kullanıcıya bilgi ver
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$rows x $cols ızgara düzeninde ağaçlar ekleniyor...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _mapboxController.plantGridTrees(rows, cols);
    }
  }

  Future<void> _askLineSpacing() async {
    final spacingCtl = TextEditingController(text: '20');
    final directionCtl = TextEditingController(text: 'doğu-batı');
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Row(
          children: [
            Icon(Icons.straight, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Şerit Dikim Ayarları'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: spacingCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ağaç Arası Mesafe (metre)',
                hintText: 'Örn: 20',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: directionCtl,
              decoration: const InputDecoration(
                labelText: 'Şerit Yönü',
                hintText: 'Örn: doğu-batı, kuzey-güney',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    
    if (ok == true) {
      final spacing = double.tryParse(spacingCtl.text) ?? 20.0;
      final direction = directionCtl.text.trim();
      
      // Kullanıcıya bilgi ver
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$spacing metre aralıklarla şerit dikim yapılıyor...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _mapboxController.plantAlongFence(spacing);
    }
  }

  Future<void> _askRandomCount() async {
    final countCtl = TextEditingController(text: '25');
    final radiusCtl = TextEditingController(text: '200');
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Row(
          children: [
            Icon(Icons.casino, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Rasgele Dikim Ayarları'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ağaç Sayısı',
                hintText: 'Örn: 25',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: radiusCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dikim Yarıçapı (metre)',
                hintText: 'Örn: 200',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    
    if (ok == true) {
      final count = int.tryParse(countCtl.text) ?? 25;
      final radius = double.tryParse(radiusCtl.text) ?? 200.0;
      
      // Kullanıcıya bilgi ver
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count adet ağaç $radius metre yarıçapında rastgele ekleniyor...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _mapboxController.plantRandomTrees(count);
    }
  }

  /// Grid arka plan oluştur
  Widget _buildGridBackground() {
    return Container(); // Grid arka planı kaldırıldı
  }

  /// Harita içeriği (Mapbox entegrasyonu)
  Widget _buildMapContent() {
    return MapboxHarita(
      width: 800,
      height: 600,
      onMapTap: (_) {},
      onCameraMove: (_) {},
      controller: _mapboxController,
      selectedTool: _selectedTool,
      currentLocation: _currentLocation,
      onFenceModeDisabled: _onFenceModeDisabled,
      onFarmDesignRequest: _onFarmDesignRequest,
    );
  }
}

/// Grid çizimi için CustomPainter
class GridPainter extends CustomPainter {
  final Color gridColor;
  final double gridSize;

  GridPainter({
    required this.gridColor,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
