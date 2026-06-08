import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_fridge/data/shopping_list_store.dart';
import 'package:my_fridge/models/food.dart';
import 'package:my_fridge/models/shopping_item.dart';
import 'package:my_fridge/screens/recipes_screen.dart';

void main() {
  test(
    'une recette en grammes utilise correctement un stock en kilogrammes',
    () {
      final recipe = RecipeSuggestion(
        emoji: '🍝',
        name: 'Test pâtes',
        time: '10 min',
        description: 'Test',
        requiredIngredients: const [
          RecipeIngredient(
            label: 'Pâtes',
            keywords: ['pâte'],
            requiredAmount: 500,
            requiredUnit: 'g',
          ),
        ],
        steps: const ['Cuire'],
      );
      final foods = [
        FoodItem(
          id: 'pasta',
          name: 'Pâtes',
          emoji: '🍝',
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          amount: 1,
          unit: 'kg',
        ),
      ];

      final match = RecipeCatalog.matchIngredients(recipe, foods).single;
      final consumption = RecipeCatalog.consumptionAmounts(recipe, foods);

      expect(match.isAvailable, isTrue);
      expect(match.missingAmount, 0);
      expect(consumption['pasta'], 0.5);
    },
  );

  test('une unité incompatible produit un manque complet', () {
    const ingredient = RecipeIngredient(
      label: 'Pâtes',
      keywords: ['pâte'],
      requiredAmount: 500,
      requiredUnit: 'g',
    );
    const match = RecipeIngredientMatch(
      ingredient: ingredient,
      isAvailable: false,
      matchedFoodAmount: 1,
      matchedFoodUnit: 'unité',
    );

    expect(match.missingAmount, 500);
  });

  test('une recette en centilitres accepte un stock en litres', () {
    final recipe = RecipeSuggestion(
      emoji: '🥛',
      name: 'Test crème',
      time: '5 min',
      description: 'Test',
      requiredIngredients: const [
        RecipeIngredient(
          label: 'Crème',
          keywords: ['crème'],
          requiredAmount: 50,
          requiredUnit: 'cl',
        ),
      ],
      steps: const ['Mélanger'],
    );
    final foods = [
      FoodItem(
        id: 'cream',
        name: 'Crème',
        emoji: '🥛',
        expiryDate: DateTime.now().add(const Duration(days: 5)),
        amount: 1,
        unit: 'l',
      ),
    ];

    final match = RecipeCatalog.matchIngredients(recipe, foods).single;
    final consumption = RecipeCatalog.consumptionAmounts(recipe, foods);

    expect(match.isAvailable, isTrue);
    expect(consumption['cream'], 0.5);
  });

  test(
    'les courses ajoutent seulement la quantité compatible manquante',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ShoppingListStore.load();
      store.addItem(
        const ShoppingItem(
          id: 'existing',
          name: 'Pâtes',
          amount: 0.2,
          unit: 'kg',
        ),
      );

      final missing = store.missingAmountFor(
        const ShoppingItem(
          id: 'desired',
          name: 'Pâtes',
          amount: 500,
          unit: 'g',
        ),
      );

      expect(missing, closeTo(300, 0.0001));
      store.addItemsUsingCompatibleUnits([
        ShoppingItem(
          id: 'complement',
          name: 'Pâtes',
          amount: missing,
          unit: 'g',
        ),
      ]);

      expect(store.items, hasLength(1));
      expect(store.items.single.unit, 'kg');
      expect(store.items.single.amount, closeTo(0.5, 0.0001));
      expect(
        store.missingAmountFor(
          const ShoppingItem(
            id: 'smaller',
            name: 'Pâtes',
            amount: 100,
            unit: 'g',
          ),
        ),
        0,
      );
    },
  );
}
