import 'package:flutter_test/flutter_test.dart';
import 'package:my_fridge/models/food.dart';
import 'package:my_fridge/models/stock_setup_defaults.dart';

void main() {
  group('FoodUnitHelper', () {
    test('propose des unités adaptées aux produits courants', () {
      expect(FoodUnitHelper.suggestForName('Jambon blanc'), 'tranche');
      expect(FoodUnitHelper.suggestForName('Œufs frais'), 'unité');
      expect(FoodUnitHelper.suggestForName('Lait demi-écrémé'), 'l');
      expect(FoodUnitHelper.suggestForName('Chips nature'), 'paquet');
      expect(FoodUnitHelper.suggestForName('Poivre noir'), 'pot');
      expect(
        FoodUnitHelper.suggestForName('Pâtes', hasMeasuredAmount: true),
        'g',
      );
      expect(FoodUnitHelper.suggestForName('Produit inconnu'), 'unité');
    });

    test('les nouvelles unités comptables restent cohérentes', () {
      expect(MeasurementHelper.normalizeUnit('paquets'), 'paquet');
      expect(MeasurementHelper.normalizeUnit('pots'), 'pot');
      expect(MeasurementHelper.label(2, 'paquet'), '2 paquets');
      expect(MeasurementHelper.logicalQuantity(3, 'pot'), 3);
      expect(MeasurementHelper.areCompatible('paquet', 'unité'), isFalse);
    });
  });

  group('FoodCategoryHelper', () {
    test('reconnaît les anciennes et nouvelles catégories', () {
      expect(FoodCategoryHelper.fromName('meat'), FoodCategory.meat);
      expect(FoodCategoryHelper.fromName('dairy'), FoodCategory.dairy);
      expect(
        FoodCategoryHelper.fromName('spicesCondiments'),
        FoodCategory.spicesCondiments,
      );
      expect(
        FoodCategoryHelper.fromName('prepared_meals'),
        FoodCategory.preparedMeals,
      );
      expect(FoodCategoryHelper.fromName('unknown'), FoodCategory.other);
    });

    test('propose des catégories plus précises par nom', () {
      expect(
        FoodCategoryHelper.suggestForName('Saumon fumé'),
        FoodCategory.seafood,
      );
      expect(
        FoodCategoryHelper.suggestForName('Pâtes complètes'),
        FoodCategory.starches,
      );
      expect(
        FoodCategoryHelper.suggestForName('Poivre noir'),
        FoodCategory.spicesCondiments,
      );
      expect(
        FoodCategoryHelper.suggestForName('Pain de mie'),
        FoodCategory.bakery,
      );
    });
  });

  group('StockSetupDefaults', () {
    test('préremplit l’emplacement choisi dans le nouvel aliment', () {
      final food = StockSetupDefaults.createFood(
        id: 'setup-test',
        name: 'Riz',
        amount: 500,
        unit: 'g',
        category: FoodCategory.starches,
        storageLocation: StorageLocation.pantry,
        expiryDate: DateTime(2026, 12, 1),
      );

      expect(food.storageLocation, StorageLocation.pantry);
      expect(food.category, FoodCategory.starches);
      expect(food.amountLabel, '500 g');
    });

    test('propose une date adaptée à chaque zone', () {
      final start = DateTime(2026, 6, 11, 18);

      expect(
        StockSetupDefaults.estimatedExpiry(StorageLocation.fridge, from: start),
        DateTime(2026, 6, 18),
      );
      expect(
        StockSetupDefaults.estimatedExpiry(
          StorageLocation.freezer,
          from: start,
        ),
        DateTime(2026, 9, 9),
      );
    });
  });
}
