import 'package:flutter_test/flutter_test.dart';
import 'package:my_fridge/models/food.dart';

void main() {
  group('MeasurementHelper', () {
    test('convertit les masses et les volumes compatibles', () {
      expect(
        MeasurementHelper.convertAmount(1, fromUnit: 'kg', toUnit: 'g'),
        1000,
      );
      expect(
        MeasurementHelper.convertAmount(1, fromUnit: 'l', toUnit: 'cl'),
        100,
      );
      expect(
        MeasurementHelper.convertAmount(50, fromUnit: 'cl', toUnit: 'ml'),
        500,
      );
      expect(
        MeasurementHelper.convertAmount(50, fromUnit: 'ml', toUnit: 'l'),
        0.05,
      );
    });

    test('normalise les pluriels mais refuse les dimensions incompatibles', () {
      expect(
        MeasurementHelper.convertAmount(2, fromUnit: 'unités', toUnit: 'unité'),
        2,
      );
      expect(
        MeasurementHelper.convertAmount(500, fromUnit: 'g', toUnit: 'ml'),
        isNull,
      );
    });

    test(
      'convertit un changement compatible et réinitialise un incompatible',
      () {
        expect(
          MeasurementHelper.amountAfterUnitChange(
            500,
            fromUnit: 'g',
            toUnit: 'kg',
          ),
          0.5,
        );
        expect(
          MeasurementHelper.amountAfterUnitChange(
            500,
            fromUnit: 'g',
            toUnit: 'ml',
          ),
          MeasurementHelper.stepFor('ml'),
        );
      },
    );

    test('affiche les petites quantités converties sans arrondi trompeur', () {
      expect(MeasurementHelper.inputValue(0.05), '0.05');
      expect(MeasurementHelper.inputValue(0.5), '0.5');
    });
  });
}
