import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_fridge/data/fridge_store.dart';
import 'package:my_fridge/models/food.dart';
import 'package:my_fridge/services/cloud_foods_service.dart';

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

  test('une valeur cloud absente ou inconnue reste dans le frigo', () {
    expect(StorageLocationHelper.fromName(null), StorageLocation.fridge);
    expect(StorageLocationHelper.fromName('unknown'), StorageLocation.fridge);
    expect(StorageLocationHelper.fromName('freezer'), StorageLocation.freezer);
  });

  test('la conversion cloud conserve ou initialise l’emplacement', () {
    final freezerFood = FoodItem(
      id: 'frozen',
      name: 'Petits pois',
      emoji: '🫛',
      expiryDate: DateTime(2026, 12, 1),
      storageLocation: StorageLocation.freezer,
    );
    final row = CloudFoodsService.toSupabaseRow(freezerFood, 'user-id');

    expect(row['storage_location'], 'freezer');

    final restoredLegacyFood = CloudFoodsService.fromSupabaseRow({
      'id': 'legacy-cloud',
      'name': 'Lait',
      'emoji': '🥛',
      'category': 'dairy',
      'quantity': 1,
      'amount': 1,
      'unit': 'l',
      'expiration_date': '2026-06-20',
    });

    expect(restoredLegacyFood.storageLocation, StorageLocation.fridge);
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
