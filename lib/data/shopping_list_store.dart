import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shopping_item.dart';

class ShoppingListStore extends ChangeNotifier {
  ShoppingListStore._(this._items);

  static const _storageKey = 'shopping_list_items';

  List<ShoppingItem> _items;

  List<ShoppingItem> get items => List.unmodifiable(_items);

  bool containsEquivalent(ShoppingItem item) {
    return _items.any((existingItem) => _canMerge(existingItem, item));
  }

  static Future<ShoppingListStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_storageKey);

    if (savedJson == null || savedJson.isEmpty) {
      return ShoppingListStore._([]);
    }

    try {
      final decoded = jsonDecode(savedJson) as List<dynamic>;
      final items = decoded
          .map((item) => ShoppingItem.fromJson(item as Map<String, dynamic>))
          .toList();
      return ShoppingListStore._(_mergeDuplicates(items));
    } catch (_) {
      return ShoppingListStore._([]);
    }
  }

  void addItem(ShoppingItem item) {
    _items = _addOrMergeItem(_items, item);
    notifyListeners();
    _save();
  }

  void addItems(List<ShoppingItem> items) {
    if (items.isEmpty) return;

    var updatedItems = _items;
    for (final item in items) {
      updatedItems = _addOrMergeItem(updatedItems, item);
    }

    _items = updatedItems;
    notifyListeners();
    _save();
  }

  void toggleItem(String id) {
    _items = [
      for (final item in _items)
        if (item.id == id) item.copyWith(isChecked: !item.isChecked) else item,
    ];
    notifyListeners();
    _save();
  }

  void deleteItem(String id) {
    _items = _items.where((item) => item.id != id).toList();
    notifyListeners();
    _save();
  }

  void deleteItemsByIds(List<String> ids) {
    if (ids.isEmpty) return;

    final idsToDelete = ids.toSet();
    _items = _items.where((item) => !idsToDelete.contains(item.id)).toList();
    notifyListeners();
    _save();
  }

  void clearChecked() {
    _items = _items.where((item) => !item.isChecked).toList();
    notifyListeners();
    _save();
  }

  void clearAll() {
    if (_items.isEmpty) return;
    _items = [];
    notifyListeners();
    _save();
  }

  Future<void> replaceAllItems(List<ShoppingItem> items) async {
    _items = _mergeDuplicates(items);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  static List<ShoppingItem> _addOrMergeItem(
    List<ShoppingItem> currentItems,
    ShoppingItem newItem,
  ) {
    final index = currentItems.indexWhere((item) => _canMerge(item, newItem));

    if (index == -1) {
      return [newItem, ...currentItems];
    }

    final updatedItems = [...currentItems];
    final existingItem = updatedItems[index];

    updatedItems[index] = existingItem.copyWith(
      amount: existingItem.amount + newItem.amount,
      isChecked: false,
    );

    return updatedItems;
  }

  static List<ShoppingItem> _mergeDuplicates(List<ShoppingItem> items) {
    var mergedItems = <ShoppingItem>[];
    for (final item in items) {
      mergedItems = _addOrMergeItem(mergedItems, item);
    }
    return mergedItems;
  }

  static bool _canMerge(ShoppingItem a, ShoppingItem b) {
    return _normalize(a.name) == _normalize(b.name) &&
        _normalizeUnit(a.unit) == _normalizeUnit(b.unit);
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static String _normalizeUnit(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('unités', 'unité')
        .replaceAll('tranches', 'tranche');
  }
}
