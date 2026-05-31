import 'food.dart';

/// Produit détecté pendant la validation du scan, avant ajout au frigo.
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

  List<FoodItem> toFoodItemsForFridge() => [food.copyWith(quantity: quantity)];
}
