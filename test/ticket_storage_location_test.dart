import 'package:flutter_test/flutter_test.dart';
import 'package:my_fridge/models/food.dart';
import 'package:my_fridge/models/ticket_analysis_result.dart';

void main() {
  Map<String, dynamic> productJson({String? storageLocation}) {
    return {
      'name': 'Produit test',
      'quantity': 1,
      'amount': 1,
      'unit': 'unité',
      'category': 'other',
      'estimatedExpirationDate': '2026-06-20T00:00:00.000',
      'storageLocation': ?storageLocation,
    };
  }

  test('lit les emplacements autorisés du résultat de scan', () {
    final result = TicketAnalysisResult.fromJsonList([
      productJson(storageLocation: 'freezer'),
      productJson(storageLocation: 'pantry'),
      productJson(storageLocation: 'spices'),
      productJson(storageLocation: 'fridge'),
    ], idPrefix: 'scan');

    expect(result.products.map((product) => product.storageLocation), [
      StorageLocation.freezer,
      StorageLocation.pantry,
      StorageLocation.spices,
      StorageLocation.fridge,
    ]);
  });

  test('utilise fridge pour un ancien résultat ou une valeur inconnue', () {
    final invalidType = productJson()..['storageLocation'] = 42;
    final result = TicketAnalysisResult.fromJsonList([
      productJson(),
      productJson(storageLocation: 'unknown'),
      invalidType,
    ], idPrefix: 'legacy');

    expect(
      result.products.map((product) => product.storageLocation),
      everyElement(StorageLocation.fridge),
    );
  });

  test('conserve l’emplacement lors de la conversion en aliment', () {
    final result = TicketAnalysisResult.fromJsonList([
      productJson(storageLocation: 'freezer'),
    ], idPrefix: 'food');

    expect(
      result.products.single.toFoodItem().storageLocation,
      StorageLocation.freezer,
    );
  });
}
