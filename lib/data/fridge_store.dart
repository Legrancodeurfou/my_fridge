import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food.dart';

/// Source de vérité partagée pour la liste d’aliments du frigo.
/// Utilisée par FridgeScreen et ScanScreen.
class FridgeStore extends ChangeNotifier {
  FridgeStore._(this._foods);

  static const _storageKey = 'fridge_foods';

  List<FoodItem> _foods;

  List<FoodItem> get foods => List.unmodifiable(_foods);

  /// Charge les aliments sauvegardés, ou les données mockées au premier lancement.
  static Future<FridgeStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_storageKey);

    if (savedJson == null || savedJson.isEmpty) {
      return FridgeStore._(FridgeMockDataSource.fetchAll());
    }

    try {
      final decoded = jsonDecode(savedJson) as List<dynamic>;
      final foods = decoded
          .map((item) => FoodItem.fromJson(item as Map<String, dynamic>))
          .toList();
      return FridgeStore._(foods);
    } catch (_) {
      return FridgeStore._(FridgeMockDataSource.fetchAll());
    }
  }

  void addFood(FoodItem food) {
    _foods = [food, ..._foods];
    notifyListeners();
    _save();
  }

  void addFoods(List<FoodItem> foods) {
    if (foods.isEmpty) return;
    _foods = [...foods, ..._foods];
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_foods.map((food) => food.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  /// Produits fictifs « détectés » sur un ticket de caisse scanné.
  static List<FoodItem> createTicketScanItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final baseId = now.millisecondsSinceEpoch;

    return [
      FoodItem(
        id: '${baseId}_0',
        name: 'Pâtes',
        emoji: '🍝',
        expiryDate: today.add(const Duration(days: 365)),
        category: FoodCategory.other,
      ),
      FoodItem(
        id: '${baseId}_1',
        name: 'Jambon',
        emoji: '🥓',
        expiryDate: today.add(const Duration(days: 5)),
        category: FoodCategory.meat,
      ),
      FoodItem(
        id: '${baseId}_2',
        name: 'Crème fraîche',
        emoji: '🥛',
        expiryDate: today.add(const Duration(days: 10)),
        category: FoodCategory.dairy,
      ),
      FoodItem(
        id: '${baseId}_3',
        name: 'Salade',
        emoji: '🥬',
        expiryDate: today.add(const Duration(days: 3)),
        category: FoodCategory.produce,
      ),
    ];
  }
}
