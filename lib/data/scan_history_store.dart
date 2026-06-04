import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food.dart';
import '../models/scan_history_item.dart';

class ScanHistoryStore extends ChangeNotifier {
  ScanHistoryStore._(this._items);

  static const _storageKey = 'scan_history_items';
  static const _maxItems = 30;

  List<ScanHistoryItem> _items;

  List<ScanHistoryItem> get items => List.unmodifiable(_items);

  List<ScanHistoryItem> recent({int limit = 3}) => _items.take(limit).toList();

  static Future<ScanHistoryStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_storageKey);

    if (savedJson == null || savedJson.isEmpty) {
      return ScanHistoryStore._([]);
    }

    try {
      final decoded = jsonDecode(savedJson) as List<dynamic>;
      final items = decoded
          .map((item) => ScanHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

      return ScanHistoryStore._(items.take(_maxItems).toList());
    } catch (_) {
      return ScanHistoryStore._([]);
    }
  }

  void addScan({
    required int detectedCount,
    required List<FoodItem> validatedFoods,
    String source = 'unknown',
    String? model,
    String? errorMessage,
  }) {
    final now = DateTime.now();

    final item = ScanHistoryItem(
      id: now.microsecondsSinceEpoch.toString(),
      scannedAt: now,
      detectedCount: detectedCount,
      validatedCount: validatedFoods.length,
      products: validatedFoods.map(ScanHistoryProduct.fromFood).toList(),
      source: source,
      model: model,
      errorMessage: errorMessage,
    );

    _items = [item, ..._items].take(_maxItems).toList();
    notifyListeners();
    _save();
  }

  void deleteScan(String id) {
    _items = _items.where((item) => item.id != id).toList();
    notifyListeners();
    _save();
  }

  void clearAll() {
    if (_items.isEmpty) return;
    _items = [];
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
