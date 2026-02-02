import 'package:flutter/material.dart';
// import 'package:mapbox_gl/mapbox_gl.dart'; // Geçici olarak devre dışı - Dart 3.5 uyumluluk sorunu
import 'package:smartfarm_xr/core/utils/mapbox_types.dart';

/// Çiftlik Nesnesi - Tüm çiftlik elemanlarının temel sınıfı
class FarmObject {
  final String id;
  final String type;
  final String name;
  final LatLng position;
  final double rotation;
  final double scale;
  final Map<String, dynamic> properties;

  FarmObject({
    required this.id,
    required this.type,
    required this.name,
    required this.position,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.properties = const {},
  });

  String get label => name;
}

/// Grid Hücresi - Çiftlik tasarım grid sistemindeki her hücre
class GridCell {
  final int row;
  final int col;
  bool isEmpty;
  FarmObject? object;
  dynamic position; // LatLng veya Offset olabilir

  GridCell({
    required this.row,
    required this.col,
    this.isEmpty = true,
    this.object,
    this.position,
  });

  GridCell copyWith({
    bool? isEmpty,
    FarmObject? object,
    dynamic position,
  }) {
    return GridCell(
      row: row,
      col: col,
      isEmpty: isEmpty ?? this.isEmpty,
      object: object ?? this.object,
      position: position ?? this.position,
    );
  }
}

/// Tasarım Aksiyonu - Undo/Redo sistemi için
class DesignAction {
  final String type; // 'add', 'remove', 'move', 'update'
  final GridCell? cell;
  final FarmObject? object;
  final Map<String, dynamic>? previousState;
  final Map<String, dynamic>? newState;

  DesignAction({
    required this.type,
    this.cell,
    this.object,
    this.previousState,
    this.newState,
  });
}

/// Arazi Sınırları Hesaplama Yardımcı Sınıfı
class Bounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  Bounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  double get width {
    // Basit mesafe hesaplama (Haversine formülü basitleştirilmiş)
    return (maxLng - minLng) * 111320 * 0.707; // Yaklaşık metre cinsinden
  }

  double get height {
    return (maxLat - minLat) * 111320; // Yaklaşık metre cinsinden
  }
}
