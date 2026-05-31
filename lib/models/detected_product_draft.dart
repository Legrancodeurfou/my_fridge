import 'food.dart';

/// Brouillon affiché à la validation du scan, avant ajout au frigo.
class DetectedProductDraft {
  DetectedProductDraft({
    required this.id,
    required this.name,
    required this.category,
    required this.estimatedExpirationDate,
    this.quantity = 1,
  }) : assert(quantity >= 1);

  final String id;
  final String name;
  final FoodCategory category;
  final DateTime estimatedExpirationDate;
  final int quantity;

  String get emoji => FoodCategoryHelper.emoji(category);

  DetectedProductDraft copyWith({
    String? id,
    String? name,
    FoodCategory? category,
    DateTime? estimatedExpirationDate,
    int? quantity,
  }) {
    return DetectedProductDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      estimatedExpirationDate:
          estimatedExpirationDate ?? this.estimatedExpirationDate,
      quantity: quantity ?? this.quantity,
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
    );
  }
}
