import 'food.dart';

/// Brouillon affiché à la validation du scan, avant ajout au frigo.
class DetectedProductDraft {
  DetectedProductDraft({
    required this.id,
    required this.name,
    required this.category,
    required this.estimatedExpirationDate,
    this.quantity = 1,
    this.amount = 1,
    this.unit = 'unité',
    this.storageLocation = StorageLocation.fridge,
  }) : assert(quantity >= 1),
       assert(amount > 0);

  final String id;
  final String name;
  final FoodCategory category;
  final DateTime estimatedExpirationDate;

  /// Nombre d'unités logiques.
  /// Exemple : 4 yaourts => quantity = 4.
  /// Exemple : 500 g de pâtes => quantity = 1.
  final int quantity;

  /// Quantité lisible pour l'utilisateur : 500 g, 20 cl, 2 tranches...
  final double amount;
  final String unit;
  final StorageLocation storageLocation;

  String get emoji => FoodCategoryHelper.emoji(category);
  String get amountLabel => MeasurementHelper.label(amount, unit);

  DetectedProductDraft copyWith({
    String? id,
    String? name,
    FoodCategory? category,
    DateTime? estimatedExpirationDate,
    int? quantity,
    double? amount,
    String? unit,
    StorageLocation? storageLocation,
  }) {
    final nextAmount = amount ?? this.amount;
    final nextUnit = unit ?? this.unit;

    return DetectedProductDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      estimatedExpirationDate:
          estimatedExpirationDate ?? this.estimatedExpirationDate,
      quantity:
          quantity ?? MeasurementHelper.logicalQuantity(nextAmount, nextUnit),
      amount: nextAmount,
      unit: nextUnit,
      storageLocation: storageLocation ?? this.storageLocation,
    );
  }

  FoodItem toFoodItem() {
    return FoodItem(
      id: id,
      name: name,
      emoji: emoji,
      expiryDate: estimatedExpirationDate,
      category: category,
      quantity: quantity,
      amount: amount,
      unit: unit,
      storageLocation: storageLocation,
    );
  }
}
