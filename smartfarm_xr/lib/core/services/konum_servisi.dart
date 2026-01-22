import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

/// Konum servisi - GPS ve navigasyon işlemleri
class KonumServisi {
  static final KonumServisi _instance = KonumServisi._internal();
  factory KonumServisi() => _instance;
  KonumServisi._internal();
  
  /// Singleton instance getter
  static KonumServisi get instance => _instance;
  
  Position? _currentPosition;

  /// Güncel konumu al
  Future<LatLng?> getCurrentLocation() async {
    try {
      // Konum izinlerini kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Konum servisi kapalı');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Konum izni reddedildi');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Konum izni kalıcı olarak reddedildi');
        return null;
      }

      // Güncel konumu al
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      // Position'ı LatLng'e dönüştür
      if (_currentPosition != null) {
        return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      }

      return null;
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
      return null;
    }
  }

  /// Konum ayarlarını aç
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Uygulama ayarlarını aç
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
