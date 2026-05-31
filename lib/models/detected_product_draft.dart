import 'food.dart';

/// Produit détecté pendant la validation du scan, avant ajout au frigo.
///
/// [quantity] sera persistée plus tard ; pour l’instant elle n’est utilisée
/// que dans l’écran de validation.
class DetectedProductDraft {
  DetectedProductDraft({
    required this.food,
    this.quantity = 1,
  }) : assert(quantity >= 1);

  final FoodItem food;
  final int quantity;

  DetectedProductDraft copyWith({FoodItem? food, int? quantity}) {
    return DetectedProductDraft(
      food: food ?? this.food,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Conversion vers le store tant que [FridgeStore] ne gère pas la quantité.
  List<FoodItem> toFoodItemsForFridge() => [food];
}
