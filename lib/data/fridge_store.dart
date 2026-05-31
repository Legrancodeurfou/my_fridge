import 'package:flutter/foundation.dart';

import '../models/food.dart';

/// Source de vérité partagée pour la liste d’aliments du frigo.
/// Utilisée par FridgeScreen et ScanScreen.
class FridgeStore extends ChangeNotifier {
  FridgeStore() : _foods = FridgeMockDataSource.fetchAll();

  List<FoodItem> _foods;

  List<FoodItem> get foods => List.unmodifiable(_foods);

  void addFood(FoodItem food) {
    _foods = [food, ..._foods];
    notifyListeners();
  }

  /// Simule l’ajout d’aliments détectés sur un ticket de caisse.
  void addTicketScanResults() {
    _foods = [..._createTicketScanItems(), ..._foods];
    notifyListeners();
  }

  List<FoodItem> _createTicketScanItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final baseId = now.millisecondsSinceEpoch;

    return [
      FoodItem(
        id: '${baseId}_0',
        name: 'Pâtes',
        emoji: '🍝',
        expiryDate: today.add(const Duration(days: 365)),
        category: FoodCategory.other,
      ),
      FoodItem(
        id: '${baseId}_1',
        name: 'Jambon',
        emoji: '🥓',
        expiryDate: today.add(const Duration(days: 5)),
        category: FoodCategory.meat,
      ),
      FoodItem(
        id: '${baseId}_2',
        name: 'Crème fraîche',
        emoji: '🥛',
        expiryDate: today.add(const Duration(days: 10)),
        category: FoodCategory.dairy,
      ),
      FoodItem(
        id: '${baseId}_3',
        name: 'Salade',
        emoji: '🥬',
        expiryDate: today.add(const Duration(days: 3)),
        category: FoodCategory.produce,
      ),
    ];
  }
}
