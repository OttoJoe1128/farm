import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  const LocalStorageService();

  Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> deleteKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<List<Map<String, dynamic>>> readCollection(String key) async {
    final raw = await readString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeCollection(String key, List<Map<String, dynamic>> items) async {
    await saveString(key, json.encode(items));
  }
}
