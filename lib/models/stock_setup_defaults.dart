import 'food.dart';

abstract final class StockSetupDefaults {
  static DateTime estimatedExpiry(StorageLocation location, {DateTime? from}) {
    final source = from ?? DateTime.now();
    final today = DateTime(source.year, source.month, source.day);
    final days = switch (location) {
      StorageLocation.fridge => 7,
      StorageLocation.pantry => 180,
      StorageLocation.freezer => 90,
      StorageLocation.spices => 365,
    };

    return today.add(Duration(days: days));
  }

  static FoodItem createFood({
    required String id,
    required String name,
    required double amount,
    required String unit,
    required FoodCategory category,
    required StorageLocation storageLocation,
    required DateTime expiryDate,
  }) {
    return FoodItem(
      id: id,
      name: name,
      emoji: FoodCategoryHelper.emoji(category),
      expiryDate: expiryDate,
      category: category,
      storageLocation: storageLocation,
      quantity: MeasurementHelper.logicalQuantity(amount, unit),
      amount: amount,
      unit: unit,
    );
  }
}
