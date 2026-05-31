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

  void updateFood(FoodItem updatedFood) {
    final index = _foods.indexWhere((food) => food.id == updatedFood.id);
    if (index == -1) return;

    _foods = [..._foods];
    _foods[index] = updatedFood;
    notifyListeners();
    _save();
  }

  void deleteFood(String foodId) {
    _foods = _foods.where((food) => food.id != foodId).toList();
    notifyListeners();
    _save();
  }

  void deleteFoodsByIds(List<String> foodIds) {
    if (foodIds.isEmpty) return;

    final idsToRemove = foodIds.toSet();
    _foods = _foods.where((food) => !idsToRemove.contains(food.id)).toList();
    notifyListeners();
    _save();
  }

  /// Consomme une unité par aliment : quantity - 1, ou suppression si quantity == 1.
  void consumeFoodsByIds(List<String> foodIds) {
    if (foodIds.isEmpty) return;

    final idsToConsume = foodIds.toSet();
    final updated = <FoodItem>[];

    for (final food in _foods) {
      if (!idsToConsume.contains(food.id)) {
        updated.add(food);
        continue;
      }

      if (food.quantity > 1) {
        updated.add(food.copyWith(quantity: food.quantity - 1));
      }
    }

    _foods = updated;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_foods.map((food) => food.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
