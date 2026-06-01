import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food.dart';

class FridgeStore extends ChangeNotifier {
  FridgeStore._(this._foods);

  static const _storageKey = 'fridge_foods';

  List<FoodItem> _foods;

  List<FoodItem> get foods => List.unmodifiable(_foods);

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

      return FridgeStore._(_mergeDuplicates(foods));
    } catch (_) {
      return FridgeStore._(FridgeMockDataSource.fetchAll());
    }
  }

  void addFood(FoodItem food) {
    _foods = _addOrMergeFood(_foods, food);
    notifyListeners();
    _save();
  }

  void addFoods(List<FoodItem> foods) {
    if (foods.isEmpty) return;

    var updatedFoods = _foods;
    for (final food in foods) {
      updatedFoods = _addOrMergeFood(updatedFoods, food);
    }

    _foods = updatedFoods;
    notifyListeners();
    _save();
  }

  void updateFood(FoodItem updatedFood) {
    final index = _foods.indexWhere((food) => food.id == updatedFood.id);
    if (index == -1) return;

    _foods = [..._foods];
    _foods[index] = updatedFood;
    _foods = _mergeDuplicates(_foods);

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

  void consumeFoodsByIds(List<String> foodIds) {
    if (foodIds.isEmpty) return;

    final idsToConsume = foodIds.toSet();
    final updated = <FoodItem>[];

    for (final food in _foods) {
      if (!idsToConsume.contains(food.id)) {
        updated.add(food);
        continue;
      }

      final newAmount = food.amount - 1;

      if (newAmount > 0) {
        updated.add(food.copyWith(amount: newAmount));
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

  static List<FoodItem> _addOrMergeFood(
    List<FoodItem> currentFoods,
    FoodItem newFood,
  ) {
    final index = currentFoods.indexWhere(
      (food) => _canMerge(food, newFood),
    );

    if (index == -1) {
      return [newFood, ...currentFoods];
    }

    final updatedFoods = [...currentFoods];
    final existingFood = updatedFoods[index];

    updatedFoods[index] = existingFood.copyWith(
      amount: existingFood.amount + newFood.amount,
      expiryDate: _earliestDate(existingFood.expiryDate, newFood.expiryDate),
    );

    return updatedFoods;
  }

  static List<FoodItem> _mergeDuplicates(List<FoodItem> foods) {
    var mergedFoods = <FoodItem>[];

    for (final food in foods) {
      mergedFoods = _addOrMergeFood(mergedFoods, food);
    }

    return mergedFoods;
  }

  static bool _canMerge(FoodItem a, FoodItem b) {
    return _normalizeName(a.name) == _normalizeName(b.name) &&
        a.unit == b.unit &&
        a.category == b.category;
  }

  static String _normalizeName(String value) {
    return value.trim().toLowerCase();
  }

  static DateTime _earliestDate(DateTime a, DateTime b) {
    return a.isBefore(b) ? a : b;
  }
}