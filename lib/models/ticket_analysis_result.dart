import 'detected_product_draft.dart';
import 'food.dart';

/// Une ligne produit telle que renvoyée par l’analyse (JSON IA futur).
class TicketRawProduct {
  const TicketRawProduct({
    required this.name,
    required this.quantity,
    required this.amount,
    required this.unit,
    required this.category,
    required this.estimatedExpirationDate,
    required this.storageLocation,
  });

  final String name;

  /// Nombre d'unités logiques.
  final int quantity;

  /// Quantité affichable : 500 g, 20 cl, 2 tranches...
  final double amount;
  final String unit;

  final FoodCategory category;
  final DateTime estimatedExpirationDate;
  final StorageLocation storageLocation;

  factory TicketRawProduct.fromJson(Map<String, dynamic> json) {
    final rawQuantity = json['quantity'];
    final quantity = switch (rawQuantity) {
      final int value => value,
      final num value => value.toInt(),
      _ => 1,
    };

    final rawAmount = json['amount'];
    final amount = switch (rawAmount) {
      final int value => value.toDouble(),
      final double value => value,
      _ => (quantity < 1 ? 1 : quantity).toDouble(),
    };

    final unit = json['unit'] as String? ?? 'unité';

    final categoryKey = json['category'] as String? ?? 'other';
    final category =
        FoodCategory.values.asNameMap()[categoryKey] ?? FoodCategory.other;
    final rawStorageLocation = json['storageLocation'];
    final storageLocation = StorageLocationHelper.fromName(
      rawStorageLocation is String ? rawStorageLocation : null,
    );

    final dateValue = json['estimatedExpirationDate'] ?? json['expiryDate'];
    final parsedDate = switch (dateValue) {
      final String value => DateTime.parse(value),
      final DateTime value => value,
      _ => DateTime.now(),
    };

    return TicketRawProduct(
      name: json['name'] as String,
      quantity: quantity < 1
          ? MeasurementHelper.logicalQuantity(amount, unit)
          : quantity,
      amount: amount <= 0 ? 1 : amount,
      unit: unit,
      category: category,
      estimatedExpirationDate: _dateOnly(parsedDate),
      storageLocation: storageLocation,
    );
  }

  DetectedProductDraft toDraft({required String id}) {
    return DetectedProductDraft(
      id: id,
      name: name,
      quantity: quantity,
      amount: amount,
      unit: unit,
      category: category,
      estimatedExpirationDate: estimatedExpirationDate,
      storageLocation: storageLocation,
    );
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

/// Résultat complet d’une analyse de ticket.
class TicketAnalysisResult {
  const TicketAnalysisResult({
    required this.rawProducts,
    required this.products,
  });

  final List<TicketRawProduct> rawProducts;
  final List<DetectedProductDraft> products;

  /// Mappe une liste JSON (réponse IA) vers des brouillons prêts pour la validation.
  factory TicketAnalysisResult.fromJsonList(
    List<dynamic> jsonList, {
    required String idPrefix,
  }) {
    final rawProducts = jsonList
        .map((item) => TicketRawProduct.fromJson(item as Map<String, dynamic>))
        .toList();

    final products = [
      for (var i = 0; i < rawProducts.length; i++)
        rawProducts[i].toDraft(id: '${idPrefix}_$i'),
    ];

    return TicketAnalysisResult(rawProducts: rawProducts, products: products);
  }
}
