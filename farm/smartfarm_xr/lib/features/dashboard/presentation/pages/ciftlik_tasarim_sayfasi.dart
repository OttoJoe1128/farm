import 'package:flutter/material.dart';
// import 'package:mapbox_gl/mapbox_gl.dart'; // Geçici olarak devre dışı - Dart 3.5 uyumluluk sorunu
import 'package:smartfarm_xr/core/utils/mapbox_types.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';
import 'package:smartfarm_xr/features/dashboard/presentation/widgets/components/ciftlik_tasarim_paneli.dart';
import 'package:smartfarm_xr/features/dashboard/presentation/widgets/components/ciftlik_models.dart';
import 'dart:math';

/// Çiftlik Tasarım Sayfası - Tam sayfa deneyimi
class CiftlikTasarimSayfasi extends StatefulWidget {
  final List<LatLng>? araziSinirlari;
  final LatLng? baslangicNoktasi;
  final List<Map<String, dynamic>>? geojsonParcels; // GeoJSON parseller
  final Map<String, dynamic>? initialDesign; // Yüklenen tasarım

  const CiftlikTasarimSayfasi({
    super.key,
    this.araziSinirlari,
    this.baslangicNoktasi,
    this.geojsonParcels,
    this.initialDesign,
  });

  @override
  State<CiftlikTasarimSayfasi> createState() => _CiftlikTasarimSayfasiState();
}

class _CiftlikTasarimSayfasiState extends State<CiftlikTasarimSayfasi>
    with TickerProviderStateMixin {
  // Animasyon kontrolcüleri
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Sayfa durumu
  bool _isDesignMode = true;
  String? _selectedTool;
  FarmObject? _selectedObject;

  // Grid sistemi
  List<List<GridCell>> _grid = [];
  double _cellSize = 2.0; // 2m x 2m grid hücreleri

  // Arazi ayarları
  double _araziGenislik = 0.0; // metre cinsinden
  double _araziUzunluk = 0.0; // metre cinsinden
  bool _manuelAraziBoyutlari = false;

  // Undo/Redo sistemi
  final List<DesignAction> _undoStack = [];
  final List<DesignAction> _redoStack = [];

  // Undo/Redo getter'ları
  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    // Eğer initial design varsa önce onu yükle, yoksa grid'i initialize et
    if (widget.initialDesign != null) {
      _loadInitialDesign();
      // initState tamamlandıktan sonra UI'yi güncelle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
    } else {
      _initializeGrid();
    }
    
    // GeoJSON varsa boyutları hesapla
    if (widget.geojsonParcels != null && widget.geojsonParcels!.isNotEmpty) {
      final bounds = _calculateBounds(widget.geojsonParcels!);
      if (bounds != null) {
        _araziGenislik = bounds.width;
        _araziUzunluk = bounds.height;
        print('📐 initState: GeoJSON boyutları hesaplandı: ${_araziGenislik.toStringAsFixed(1)}x${_araziUzunluk.toStringAsFixed(1)}m');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }
  
  void _loadInitialDesign() {
    final design = widget.initialDesign!;
    final designData = design['design_data'] ?? {};
    
    print('🔄 Design yükleniyor: ${design['design_name']}');
    print('📊 Design data keys: ${designData.keys.toList()}');
    
    // Arazi boyutlarını yükle - önce GeoJSON'dan hesapla, sonra kaydedilen değerleri kullan
    _cellSize = (designData['cellSize'] ?? 2.0).toDouble();
    
    // Önce GeoJSON'dan boyutları hesapla
    if (widget.geojsonParcels != null && widget.geojsonParcels!.isNotEmpty) {
      final bounds = _calculateBounds(widget.geojsonParcels!);
      if (bounds != null) {
        _araziGenislik = bounds.width;
        _araziUzunluk = bounds.height;
        print('📐 GeoJSON\'dan hesaplanan boyutlar: ${_araziGenislik.toStringAsFixed(1)}x${_araziUzunluk.toStringAsFixed(1)}m');
      } else {
        _araziGenislik = (designData['araziGenislik'] ?? 100.0).toDouble();
        _araziUzunluk = (designData['araziUzunluk'] ?? 100.0).toDouble();
      }
    } else {
      // GeoJSON yoksa kaydedilen değerleri kullan
      _araziGenislik = (designData['araziGenislik'] ?? 100.0).toDouble();
      _araziUzunluk = (designData['araziUzunluk'] ?? 100.0).toDouble();
    }
    
    
    print('📏 Arazi boyutları: ${_araziGenislik}x${_araziUzunluk}m, Hücre: ${_cellSize}m');
    
    // Grid'i yükle
    final gridData = designData['grid'] ?? [];
    print('🔢 Grid data length: ${gridData.length}');
    
    if (gridData.isNotEmpty) {
      _grid = gridData.map<List<GridCell>>((row) {
        return (row as List).map<GridCell>((cellData) {
          final cell = GridCell(
            row: cellData['row'] ?? 0,
            col: cellData['col'] ?? 0,
            position: LatLng(0.0, 0.0), // Varsayılan pozisyon
            isEmpty: cellData['isEmpty'] ?? true,
          );
          
          // Eğer hücrede obje varsa yükle
          if (cellData['object'] != null) {
            final objectData = cellData['object'];
            final position = objectData['position'];
            cell.object = FarmObject(
              id: objectData['id'] ?? '',
              type: objectData['type'] ?? 'tree',
              name: objectData['name'] ?? objectData['type'] ?? 'tree',
              position: LatLng(
                position['lat'] ?? 0.0,
                position['lng'] ?? 0.0,
              ),
              rotation: (objectData['rotation'] ?? 0.0).toDouble(),
              scale: (objectData['scale'] ?? 1.0).toDouble(),
              properties: Map<String, dynamic>.from(objectData['properties'] ?? {}),
            );
            print('🏠 Obje yüklendi: ${cell.object!.type} at (${cell.row}, ${cell.col})');
          }
          
          return cell;
        }).toList();
      }).toList();
      
      print('✅ Grid yüklendi: ${_grid.length}x${_grid.isNotEmpty ? _grid.first.length : 0}');
      
    } else {
      print('⚠️ Grid data boş, varsayılan grid oluşturuluyor');
      // Grid data boşsa varsayılan grid oluştur
      _initializeEmptyGrid();
    }
    
    print('✅ Initial design yüklendi: ${design['design_name']}');
    
    // UI'yi güncelle
    setState(() {});
  }

  void _initializeEmptyGrid() {
    // Boş grid oluştur - sadece boyutları ayarla
    final rows = (_araziUzunluk / _cellSize).ceil();
    final cols = (_araziGenislik / _cellSize).ceil();
    
    _grid = List.generate(rows, (row) {
      return List.generate(cols, (col) {
        return GridCell(
          row: row,
          col: col,
          position: LatLng(0.0, 0.0),
          isEmpty: true,
        );
      });
    });
    
    setState(() {});
    print('🔧 Boş grid oluşturuldu: ${rows}x${cols} hücre');
  }

  void _initializeGrid() {
    // GeoJSON parselleri varsa onları kullan, yoksa çit sistemi kullan
    if (widget.geojsonParcels != null && widget.geojsonParcels!.isNotEmpty) {
      _initializeGridFromGeoJSON();
      return;
    }
    
    if (widget.araziSinirlari == null || widget.araziSinirlari!.isEmpty) return;

    // Arazi sınırlarından grid boyutlarını hesapla
    final bounds = _calculateAraziBounds();
    final rows = ((bounds.height / _cellSize) + 1).round();
    final cols = ((bounds.width / _cellSize) + 1).round();

    // Grid'i oluştur
    _grid = List.generate(rows, (row) {
      return List.generate(cols, (col) {
        return GridCell(
          row: row,
          col: col,
          position: LatLng(
            bounds.southwest.latitude + (row * _cellSize / 111000),
            bounds.southwest.longitude + (col * _cellSize / (111000 * cos(bounds.southwest.latitude * pi / 180))),
          ),
          isEmpty: true,
        );
      });
    });

    // Arazi boyutlarını hesapla
    _araziGenislik = bounds.width;
    _araziUzunluk = bounds.height;
  }

  void _initializeGridFromGeoJSON() {
    if (widget.geojsonParcels == null || widget.geojsonParcels!.isEmpty) return;

    // GeoJSON parsellerinden toplam alan ve boyutları hesapla
    final geoJsonBounds = _calculateGeoJSONBounds();
    final totalArea = _calculateGeoJSONTotalArea();
    
    // Arazi boyutlarını GeoJSON'dan hesapla
    _araziGenislik = geoJsonBounds.width;
    _araziUzunluk = geoJsonBounds.height;
    
    print('🗺️ GeoJSON Grid Başlatıldı:');
    print('   📏 Genişlik: ${_araziGenislik.toStringAsFixed(2)}m');
    print('   📏 Uzunluk: ${_araziUzunluk.toStringAsFixed(2)}m');
    print('   📐 Toplam Alan: ${(totalArea / 10000).toStringAsFixed(4)} hektar');
    print('   📦 Parsel Sayısı: ${widget.geojsonParcels!.length}');

    final rows = ((_araziUzunluk / _cellSize) + 1).round();
    final cols = ((_araziGenislik / _cellSize) + 1).round();

    // Grid'i oluştur
    _grid = List.generate(rows, (row) {
      return List.generate(cols, (col) {
        return GridCell(
          row: row,
          col: col,
          position: LatLng(
            geoJsonBounds.southwest.latitude + (row * _cellSize / 111000),
            geoJsonBounds.southwest.longitude + (col * _cellSize / 111000),
          ),
          isEmpty: true,
        );
      });
    });

    setState(() {});
  }

  void _updateGridFromManuelBoyutlar() {
    if (!_manuelAraziBoyutlari || _araziGenislik <= 0 || _araziUzunluk <= 0) return;

    final rows = (_araziUzunluk / _cellSize + 1).round();
    final cols = (_araziGenislik / _cellSize + 1).round();

    // Grid'i yeniden oluştur
    _grid = List.generate(rows, (row) {
      return List.generate(cols, (col) {
        return GridCell(
          row: row,
          col: col,
          position: LatLng(
            widget.araziSinirlari?.isNotEmpty == true ? widget.araziSinirlari!.first.latitude + (row * _cellSize / 111000) : 0,
            widget.araziSinirlari?.isNotEmpty == true ? widget.araziSinirlari!.first.longitude + (col * _cellSize / (111000 * cos(widget.araziSinirlari!.first.latitude * pi / 180))) : 0,
          ),
          isEmpty: true,
        );
      });
    });

    setState(() {});
  }

  double _calculateAraziGenislik() {
    // GeoJSON parselleri varsa onları kullan
    if (widget.geojsonParcels != null && widget.geojsonParcels!.isNotEmpty) {
      final bounds = _calculateGeoJSONBounds();
      return bounds.width;
    }
    
    if (widget.araziSinirlari?.isEmpty != false) return 0.0;
    final bounds = _calculateAraziBounds();
    return bounds.width;
  }

  double _calculateAraziUzunluk() {
    // GeoJSON parselleri varsa onları kullan
    if (widget.geojsonParcels != null && widget.geojsonParcels!.isNotEmpty) {
      final bounds = _calculateGeoJSONBounds();
      return bounds.height;
    }
    
    if (widget.araziSinirlari?.isEmpty != false) return 0.0;
    final bounds = _calculateAraziBounds();
    return bounds.height;
  }

  LatLngBounds _calculateAraziBounds() {
    if (widget.araziSinirlari?.isEmpty != false) {
      return LatLngBounds(
        northeast: const LatLng(0, 0),
        southwest: const LatLng(0, 0),
      );
    }

    double minLat = widget.araziSinirlari!.first.latitude;
    double maxLat = widget.araziSinirlari!.first.latitude;
    double minLng = widget.araziSinirlari!.first.longitude;
    double maxLng = widget.araziSinirlari!.first.longitude;

    for (final point in widget.araziSinirlari!) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    return LatLngBounds(
      northeast: LatLng(maxLat, maxLng),
      southwest: LatLng(minLat, minLng),
    );
  }

  double _calculateAraziAlani() {
    // GeoJSON parselleri varsa onları kullan
    if (widget.geojsonParcels != null && widget.geojsonParcels!.isNotEmpty) {
      return _calculateGeoJSONTotalArea();
    }
    
    if ((widget.araziSinirlari?.length ?? 0) < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < widget.araziSinirlari!.length; i++) {
      final j = (i + 1) % widget.araziSinirlari!.length;
      area += widget.araziSinirlari![i].latitude * widget.araziSinirlari![j].longitude;
      area -= widget.araziSinirlari![j].latitude * widget.araziSinirlari![i].longitude;
    }

    return (area.abs() * 111000 * 111000) / 2; // m² cinsinden
  }

  /// GeoJSON parsellerinden toplam alan hesapla (m²)
  double _calculateGeoJSONTotalArea() {
    if (widget.geojsonParcels == null || widget.geojsonParcels!.isEmpty) return 0.0;
    
    double totalArea = 0.0;
    for (var parcel in widget.geojsonParcels!) {
      double area = parcel['area']?.toDouble() ?? 0.0;
      totalArea += area;
    }
    
    return totalArea;
  }

  /// GeoJSON parsellerinden bounds hesapla
  LatLngBounds _calculateGeoJSONBounds() {
    if (widget.geojsonParcels == null || widget.geojsonParcels!.isEmpty) {
      return LatLngBounds(
        northeast: const LatLng(0, 0),
        southwest: const LatLng(0, 0),
      );
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var parcel in widget.geojsonParcels!) {
      List<dynamic> polygonData = parcel['polygon'] ?? [];
      
      for (var coord in polygonData) {
        if (coord is List && coord.length >= 2) {
          double lng = coord[0].toDouble();
          double lat = coord[1].toDouble();
          
          minLat = min(minLat, lat);
          maxLat = max(maxLat, lat);
          minLng = min(minLng, lng);
          maxLng = max(maxLng, lng);
        }
      }
    }

    return LatLngBounds(
      northeast: LatLng(maxLat, maxLng),
      southwest: LatLng(minLat, minLng),
    );
  }

  void _startDesignMode() {
    setState(() {
      _isDesignMode = true;
    });
  }



  void _exitDesignMode() {
    setState(() {
      _isDesignMode = false;
      _selectedTool = null;
      _selectedObject = null;
    });
  }

  void _selectTool(String tool) {
    setState(() {
      if (tool == 'save') {
        _saveDesign();
      } else if (tool == 'exit') {
        _exitDesignMode();
      } else {
        _selectedTool = tool;
        debugPrint('🔧 Araç seçildi: $tool');
        
        // Araç durumuna göre UI güncelle
        switch (tool) {
          case 'select':
            debugPrint('✅ Seçim modu aktif');
            break;
          case 'move':
            debugPrint('✅ Taşıma modu aktif');
            break;
          case 'rotate':
            debugPrint('✅ Döndürme modu aktif');
            break;
          case 'scale':
            debugPrint('✅ Boyutlandırma modu aktif');
            break;
        }
      }
    });
  }

  void _addObject(String type) {
    // TODO: Implement object addition
    setState(() {});
  }

  void _saveDesign() {
    // TODO: Implement design saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎯 Tasarım kaydedildi!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _undo() {
    if (_undoStack.isEmpty) return;

    final action = _undoStack.removeLast();
    _redoStack.add(action);

    // TODO: Implement undo logic
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    final action = _redoStack.removeLast();
    _undoStack.add(action);

    // TODO: Implement redo logic
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            constraints: const BoxConstraints(
              minWidth: 400,
              minHeight: 600,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildDesignMode(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radius),
          topRight: Radius.circular(AppSpacing.radius),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.agriculture,
              color: AppColors.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Çiftlik Tasarım Platformu',
                  style: AppTextStyles.headline.copyWith(
                    color: AppColors.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Professional Farm Design Studio',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.onPrimary.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderActions(),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeaderButton(
          icon: Icons.undo,
          tooltip: 'Geri Al',
          onPressed: _canUndo ? _undo : null,
          color: _canUndo ? Colors.white : Colors.white.withOpacity(0.5),
        ),
        _buildHeaderButton(
          icon: Icons.redo,
          tooltip: 'İleri Al',
          onPressed: _canRedo ? _redo : null,
          color: _canRedo ? Colors.white : Colors.white.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        _buildHeaderButton(
          icon: Icons.close,
          tooltip: 'Kapat',
          onPressed: () => Navigator.of(context).pop(),
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1),
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }



  Widget _buildDesignMode() {
    // GeoJSON varsa boyutları tekrar hesapla
    if (widget.geojsonParcels != null && widget.geojsonParcels!.isNotEmpty) {
      final bounds = _calculateBounds(widget.geojsonParcels!);
      if (bounds != null) {
        _araziGenislik = bounds.width;
        _araziUzunluk = bounds.height;
        print('🔧 _buildDesignMode: Boyutlar güncellendi: ${_araziGenislik.toStringAsFixed(1)}x${_araziUzunluk.toStringAsFixed(1)}m');
      }
    }
    
    return CiftlikTasarimPaneli(
      araziSinirlari: widget.araziSinirlari ?? [],
      baslangicNoktasi: widget.baslangicNoktasi,
      geojsonParcels: widget.geojsonParcels, // GeoJSON parseller
      customCellSize: _cellSize,
      customWidth: _araziGenislik,
      customHeight: _araziUzunluk,
      useManualDimensions: _manuelAraziBoyutlari,
      initialGrid: _grid, // Yüklenen grid'i aktar
    );
  }





  Widget _buildGridCanvas() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(AppSpacing.small),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.small),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth - 40; // margin için
            final maxHeight = constraints.maxHeight - 40;

            // Grid boyutlarını hesapla
            final gridWidth = _grid.isNotEmpty ? _grid.first.length : 0;
            final gridHeight = _grid.length;

            // Hücre boyutunu responsive yap
            final cellSize = gridWidth > 0 && gridHeight > 0
                ? (maxWidth / gridWidth).clamp(20.0, 100.0)
                : 50.0;

            final canvasWidth = gridWidth * cellSize;
            final canvasHeight = gridHeight * cellSize;

            return InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.1,
              maxScale: 5.0,
              child: CustomPaint(
                size: Size(canvasWidth, canvasHeight),
                painter: GridPainter(
                  grid: _grid,
                  cellSize: cellSize,
                  selectedObject: _selectedObject,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildObjectPalette() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(
          top: BorderSide(
            color: AppColors.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: AppColors.primary, size: 16),
              const SizedBox(width: AppSpacing.small),
              Text(
                'Çiftlik Objeleri',
                style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${_grid.length * (_grid.isNotEmpty ? _grid.first.length : 0)} hücre',
                style: AppTextStyles.body.copyWith(
                  fontSize: 11,
                  color: AppColors.primary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildObjectButton('barn', 'Ahır', Icons.home_work),
                  _buildObjectButton('silo', 'Depo', Icons.warehouse),
                  _buildObjectButton('tree', 'Ağaç', Icons.park),
                  // _buildObjectButton('fence', 'Çit', Icons.fence), // Çit sistemi kaldırıldı
                  _buildObjectButton('well', 'Kuyu', Icons.water_drop),
                  _buildObjectButton('equipment', 'Ekipman', Icons.agriculture),
                  _buildObjectButton('sensor', 'Sensör', Icons.sensors),
                  _buildObjectButton('camera', 'Kamera', Icons.camera_alt),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectButton(String type, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.small),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.small),
              border: Border.all(
                color: AppColors.outline.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: () => _addObject(type),
              icon: Icon(icon, color: AppColors.primary),
              tooltip: label,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            label,
            style: AppTextStyles.body.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAraziAyarlariPanel() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.small),
        border: Border.all(color: AppColors.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  'Arazi Ayarları',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),

          // Manuel arazi boyutları toggle
          Row(
            children: [
              Switch(
                value: _manuelAraziBoyutlari,
                onChanged: (value) => setState(() {
                  _manuelAraziBoyutlari = value;
                  if (value) {
                    _araziGenislik = _calculateAraziGenislik();
                    _araziUzunluk = _calculateAraziUzunluk();
                  }
                }),
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  'Manuel Arazi Boyutları',
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),

          if (_manuelAraziBoyutlari) ...[
            const SizedBox(height: AppSpacing.medium),

            // Genişlik input - responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                return isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildDimensionInput(
                              'Genişlik (metre)',
                              _araziGenislik,
                              (value) {
                                setState(() {
                                  _araziGenislik = value;
                                  _updateGridFromManuelBoyutlar();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.medium),
                          Expanded(
                            child: _buildDimensionInput(
                              'Uzunluk (metre)',
                              _araziUzunluk,
                              (value) {
                                setState(() {
                                  _araziUzunluk = value;
                                  _updateGridFromManuelBoyutlar();
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildDimensionInput(
                            'Genişlik (metre)',
                            _araziGenislik,
                            (value) {
                              setState(() {
                                _araziGenislik = value;
                                _updateGridFromManuelBoyutlar();
                              });
                            },
                          ),
                          const SizedBox(height: AppSpacing.medium),
                          _buildDimensionInput(
                            'Uzunluk (metre)',
                            _araziUzunluk,
                            (value) {
                              setState(() {
                                _araziUzunluk = value;
                                _updateGridFromManuelBoyutlar();
                              });
                            },
                          ),
                        ],
                      );
              },
            ),

            const SizedBox(height: AppSpacing.medium),

            // Hücre boyutu ayarı
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grid Hücre Boyutu: ${_cellSize.toStringAsFixed(1)}m x ${_cellSize.toStringAsFixed(1)}m',
                  style: AppTextStyles.body.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Slider(
                  value: _cellSize,
                  min: 1.0,
                  max: 10.0,
                  divisions: 18,
                  label: '${_cellSize.toStringAsFixed(1)}m',
                  onChanged: (value) {
                    setState(() {
                      _cellSize = value;
                      _updateGridFromManuelBoyutlar();
                    });
                  },
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.outline.withOpacity(0.3),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.medium),

            // Grid bilgileri
            Container(
              padding: const EdgeInsets.all(AppSpacing.small),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.grid_on, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grid Boyutu: ${_grid.length} x ${_grid.isNotEmpty ? _grid.first.length : 0} hücre',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Toplam Hücre: ${_grid.length * (_grid.isNotEmpty ? _grid.first.length : 0)}',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 11,
                            color: AppColors.primary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDimensionInput(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value.toStringAsFixed(1),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Örn: 50.0',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            isDense: true,
          ),
          onChanged: (textValue) {
            final newValue = double.tryParse(textValue) ?? 0.0;
            onChanged(newValue);
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.small),
        border: Border.all(color: AppColors.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                ),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // GeoJSON'dan bounds hesapla
  LatLngBounds? _calculateBounds(List<Map<String, dynamic>> geojsonParcels) {
    if (geojsonParcels.isEmpty) return null;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final parcel in geojsonParcels) {
      final polygon = parcel['polygon'] as List<dynamic>?;
      if (polygon != null) {
        for (final coord in polygon) {
          if (coord is List && coord.length >= 2) {
            final lng = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            
            minLat = min(minLat, lat);
            maxLat = max(maxLat, lat);
            minLng = min(minLng, lng);
            maxLng = max(maxLng, lng);
          }
        }
      }
    }

    if (minLat != double.infinity) {
      return LatLngBounds(
        northeast: LatLng(maxLat, maxLng),
        southwest: LatLng(minLat, minLng),
      );
    }
    return null;
  }
}

// Helper classes

class LatLngBounds {
  final LatLng northeast;
  final LatLng southwest;

  LatLngBounds({
    required this.northeast,
    required this.southwest,
  });

  double get width => (northeast.longitude - southwest.longitude) * 111000 * cos(southwest.latitude * pi / 180);
  double get height => (northeast.latitude - southwest.latitude) * 111000;
}

class GridPainter extends CustomPainter {
  final List<List<GridCell>> grid;
  final double cellSize;
  final FarmObject? selectedObject;

  GridPainter({
    required this.grid,
    required this.cellSize,
    this.selectedObject,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outline.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Grid çizgileri
    for (int row = 0; row <= grid.length; row++) {
      final y = row * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (int col = 0; col <= (grid.isNotEmpty ? grid.first.length : 0); col++) {
      final x = col * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Undo/Redo system
enum ActionType { add, delete, modify }

class DesignAction {
  final ActionType type;
  final FarmObject object;
  final String layer;

  DesignAction({
    required this.type,
    required this.object,
    required this.layer,
  });
}
