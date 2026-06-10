import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_fridge/data/fridge_store.dart';
import 'package:my_fridge/models/food.dart';

void main() {
  test('une ancienne donnée sans emplacement reste dans le frigo', () {
    final food = FoodItem.fromJson({
      'id': 'legacy',
      'name': 'Lait',
      'emoji': '🥛',
      'expiryDate': '2026-06-20T00:00:00.000',
      'category': 'dairy',
      'quantity': 1,
      'amount': 1,
      'unit': 'l',
    });

    expect(food.storageLocation, StorageLocation.fridge);
  });

  test('deux produits identiques dans deux zones ne fusionnent pas', () async {
    SharedPreferences.setMockInitialValues({
      'fridge_foods': jsonEncode(<Map<String, dynamic>>[]),
    });
    final store = await FridgeStore.load();
    final expiryDate = DateTime(2026, 7, 1);

    store.addFoods([
      FoodItem(
        id: 'fridge-cheese',
        name: 'Emmental',
        emoji: '🧀',
        expiryDate: expiryDate,
        category: FoodCategory.dairy,
        storageLocation: StorageLocation.fridge,
        amount: 200,
        unit: 'g',
      ),
      FoodItem(
        id: 'freezer-cheese',
        name: 'Emmental',
        emoji: '🧀',
        expiryDate: expiryDate,
        category: FoodCategory.dairy,
        storageLocation: StorageLocation.freezer,
        amount: 200,
        unit: 'g',
      ),
    ]);

    expect(store.foods, hasLength(2));
    expect(store.foods.map((food) => food.storageLocation).toSet(), {
      StorageLocation.fridge,
      StorageLocation.freezer,
    });
  });

  test('copyWith conserve ou modifie l’emplacement', () {
    final food = FoodItem(
      id: 'spices',
      name: 'Paprika',
      emoji: '🌶️',
      expiryDate: DateTime(2027, 1, 1),
      storageLocation: StorageLocation.spices,
    );

    expect(food.copyWith(amount: 2).storageLocation, StorageLocation.spices);
    expect(
      food.copyWith(storageLocation: StorageLocation.pantry).storageLocation,
      StorageLocation.pantry,
    );
  });
}
