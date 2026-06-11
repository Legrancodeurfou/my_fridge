import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ExpiryUrgency { expired, warning, safe }

enum StorageLocation { fridge, freezer, pantry, spices }

abstract final class StorageLocationHelper {
  static StorageLocation fromName(String? value) {
    return StorageLocation.values.asNameMap()[value] ?? StorageLocation.fridge;
  }

  static String label(StorageLocation location) {
    return switch (location) {
      StorageLocation.fridge => 'Frigo',
      StorageLocation.freezer => 'Congélateur',
      StorageLocation.pantry => 'Placard',
      StorageLocation.spices => 'Épices',
    };
  }

  static IconData icon(StorageLocation location) {
    return switch (location) {
      StorageLocation.fridge => Icons.kitchen_outlined,
      StorageLocation.freezer => Icons.ac_unit_rounded,
      StorageLocation.pantry => Icons.inventory_2_outlined,
      StorageLocation.spices => Icons.spa_outlined,
    };
  }
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.expiryDate,
    this.category = FoodCategory.other,
    this.storageLocation = StorageLocation.fridge,
    this.quantity = 1,
    this.amount = 1,
    this.unit = 'unité',
  }) : assert(quantity >= 1),
       assert(amount > 0);

  final String id;
  final String name;
  final String emoji;
  final DateTime expiryDate;
  final FoodCategory category;
  final StorageLocation storageLocation;

  /// Nombre d'unités logiques pour les stats et la consommation.
  /// Exemple : 4 yaourts => quantity = 4.
  /// Exemple : 500 g de pâtes => quantity = 1.
  final int quantity;

  /// Quantité lisible pour cuisiner : 500 g, 20 cl, 2 tranches, etc.
  final double amount;
  final String unit;

  String get amountLabel => MeasurementHelper.label(amount, unit);

  FoodItem copyWith({
    String? id,
    String? name,
    String? emoji,
    DateTime? expiryDate,
    FoodCategory? category,
    StorageLocation? storageLocation,
    int? quantity,
    double? amount,
    String? unit,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      expiryDate: expiryDate ?? this.expiryDate,
      category: category ?? this.category,
      storageLocation: storageLocation ?? this.storageLocation,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'expiryDate': expiryDate.toIso8601String(),
      'category': category.name,
      'storageLocation': storageLocation.name,
      'quantity': quantity,
      'amount': amount,
      'unit': unit,
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
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

    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      category: FoodCategoryHelper.fromName(json['category'] as String?),
      storageLocation: StorageLocationHelper.fromName(
        json['storageLocation'] as String?,
      ),
      quantity: quantity < 1 ? 1 : quantity,
      amount: amount <= 0 ? 1 : amount,
      unit: json['unit'] as String? ?? 'unité',
    );
  }
}

abstract final class MeasurementHelper {
  static const units = [
    'g',
    'kg',
    'ml',
    'cl',
    'l',
    'unité',
    'tranche',
    'paquet',
    'pot',
  ];

  static String normalizeUnit(String unit) {
    return unit
        .trim()
        .toLowerCase()
        .replaceAll('unités', 'unité')
        .replaceAll('tranches', 'tranche')
        .replaceAll('paquets', 'paquet')
        .replaceAll('pots', 'pot');
  }

  static bool areCompatible(String firstUnit, String secondUnit) {
    final firstDimension = _dimensionFor(firstUnit);
    return firstDimension != null &&
        firstDimension == _dimensionFor(secondUnit);
  }

  static double? convertAmount(
    double amount, {
    required String fromUnit,
    required String toUnit,
  }) {
    final from = normalizeUnit(fromUnit);
    final to = normalizeUnit(toUnit);

    if (!areCompatible(from, to)) return null;

    final amountInBaseUnit = amount * _factorToBaseUnit(from);
    return amountInBaseUnit / _factorToBaseUnit(to);
  }

  static double amountAfterUnitChange(
    double amount, {
    required String fromUnit,
    required String toUnit,
  }) {
    return convertAmount(amount, fromUnit: fromUnit, toUnit: toUnit) ??
        stepFor(toUnit);
  }

  static String label(double amount, String unit) {
    final formattedAmount = inputValue(amount);
    final displayUnit = _pluralize(normalizeUnit(unit), amount);
    return '$formattedAmount $displayUnit';
  }

  static String inputValue(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }
    return amount
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static double stepFor(String unit) {
    return switch (normalizeUnit(unit)) {
      'g' => 50,
      'kg' => 0.1,
      'ml' => 50,
      'cl' => 5,
      'l' => 0.5,
      'tranche' => 1,
      'paquet' => 1,
      'pot' => 1,
      'unité' => 1,
      _ => 1,
    };
  }

  static int logicalQuantity(double amount, String unit) {
    final normalizedUnit = normalizeUnit(unit);
    if (normalizedUnit == 'unité' ||
        normalizedUnit == 'tranche' ||
        normalizedUnit == 'paquet' ||
        normalizedUnit == 'pot') {
      return amount.round().clamp(1, 9999);
    }
    return 1;
  }

  static String? _dimensionFor(String unit) {
    return switch (normalizeUnit(unit)) {
      'g' || 'kg' => 'mass',
      'ml' || 'cl' || 'l' => 'volume',
      'unité' => 'unit',
      'tranche' => 'slice',
      'paquet' => 'package',
      'pot' => 'jar',
      _ => null,
    };
  }

  static double _factorToBaseUnit(String unit) {
    return switch (normalizeUnit(unit)) {
      'kg' => 1000,
      'cl' => 10,
      'l' => 1000,
      _ => 1,
    };
  }

  static String _pluralize(String unit, double amount) {
    if (amount <= 1) return unit;
    return switch (unit) {
      'unité' => 'unités',
      'tranche' => 'tranches',
      'paquet' => 'paquets',
      'pot' => 'pots',
      _ => unit,
    };
  }
}

enum FoodCategory {
  dairy,
  produce,
  meat,
  other,
  seafood,
  starches,
  savoryGrocery,
  sweetGrocery,
  beverages,
  frozen,
  spicesCondiments,
  bakery,
  preparedMeals,
}

abstract final class FoodCategoryHelper {
  static FoodCategory fromName(String? value) {
    if (value == null) return FoodCategory.other;

    return FoodCategory.values.asNameMap()[value] ??
        switch (value.trim().toLowerCase()) {
          'fish' || 'seafood' => FoodCategory.seafood,
          'starch' || 'cereals' => FoodCategory.starches,
          'savory_grocery' => FoodCategory.savoryGrocery,
          'sweet_grocery' => FoodCategory.sweetGrocery,
          'spices_condiments' => FoodCategory.spicesCondiments,
          'prepared_meals' => FoodCategory.preparedMeals,
          _ => FoodCategory.other,
        };
  }

  static String label(FoodCategory category) {
    return switch (category) {
      FoodCategory.dairy => 'Produits laitiers',
      FoodCategory.produce => 'Fruits & légumes',
      FoodCategory.meat => 'Viande & charcuterie',
      FoodCategory.seafood => 'Poisson & fruits de mer',
      FoodCategory.starches => 'Féculents & céréales',
      FoodCategory.savoryGrocery => 'Épicerie salée',
      FoodCategory.sweetGrocery => 'Épicerie sucrée',
      FoodCategory.beverages => 'Boissons',
      FoodCategory.frozen => 'Surgelés',
      FoodCategory.spicesCondiments => 'Épices & condiments',
      FoodCategory.bakery => 'Boulangerie',
      FoodCategory.preparedMeals => 'Plats préparés',
      FoodCategory.other => 'Autre',
    };
  }

  static String emoji(FoodCategory category) {
    return switch (category) {
      FoodCategory.dairy => '🥛',
      FoodCategory.produce => '🥬',
      FoodCategory.meat => '🥩',
      FoodCategory.seafood => '🐟',
      FoodCategory.starches => '🍝',
      FoodCategory.savoryGrocery => '🥫',
      FoodCategory.sweetGrocery => '🍪',
      FoodCategory.beverages => '🥤',
      FoodCategory.frozen => '❄️',
      FoodCategory.spicesCondiments => '🧂',
      FoodCategory.bakery => '🥖',
      FoodCategory.preparedMeals => '🍲',
      FoodCategory.other => '🍽️',
    };
  }

  static IconData icon(FoodCategory category) {
    return switch (category) {
      FoodCategory.dairy => Icons.egg_alt_outlined,
      FoodCategory.produce => Icons.eco_outlined,
      FoodCategory.meat => Icons.lunch_dining_outlined,
      FoodCategory.seafood => Icons.set_meal_outlined,
      FoodCategory.starches => Icons.rice_bowl_outlined,
      FoodCategory.savoryGrocery => Icons.inventory_2_outlined,
      FoodCategory.sweetGrocery => Icons.cookie_outlined,
      FoodCategory.beverages => Icons.local_drink_outlined,
      FoodCategory.frozen => Icons.ac_unit_rounded,
      FoodCategory.spicesCondiments => Icons.spa_outlined,
      FoodCategory.bakery => Icons.bakery_dining_outlined,
      FoodCategory.preparedMeals => Icons.soup_kitchen_outlined,
      FoodCategory.other => Icons.restaurant_outlined,
    };
  }

  static FoodCategory suggestForName(String name) {
    final normalized = _normalizeProductName(name);

    if (_containsAny(normalized, ['glace', 'surgel', 'frozen'])) {
      return FoodCategory.frozen;
    }
    if (_containsAny(normalized, [
      'poivre',
      'sel',
      'paprika',
      'curry',
      'epice',
      'herbe',
      'bouillon',
      'moutarde',
      'ketchup',
      'mayonnaise',
    ])) {
      return FoodCategory.spicesCondiments;
    }
    if (_containsAny(normalized, [
      'saumon',
      'thon',
      'cabillaud',
      'poisson',
      'crevette',
      'moule',
      'fruit de mer',
    ])) {
      return FoodCategory.seafood;
    }
    if (_containsAny(normalized, [
      'jambon',
      'bacon',
      'charcuterie',
      'steak',
      'poulet',
      'viande',
      'saucisse',
      'lardon',
    ])) {
      return FoodCategory.meat;
    }
    if (_containsAny(normalized, [
      'lait',
      'creme',
      'fromage',
      'emmental',
      'yaourt',
      'beurre',
      'oeuf',
    ])) {
      return FoodCategory.dairy;
    }
    if (_containsAny(normalized, [
      'pate',
      'riz',
      'semoule',
      'farine',
      'cereale',
      'avoine',
      'quinoa',
      'lentille',
    ])) {
      return FoodCategory.starches;
    }
    if (_containsAny(normalized, [
      'chips',
      'conserve',
      'sauce',
      'huile',
      'vinaigre',
      'olive',
      'cracker',
    ])) {
      return FoodCategory.savoryGrocery;
    }
    if (_containsAny(normalized, [
      'biscuit',
      'chocolat',
      'bonbon',
      'sucre',
      'confiture',
      'gateau',
    ])) {
      return FoodCategory.sweetGrocery;
    }
    if (_containsAny(normalized, [
      'jus',
      'eau',
      'soda',
      'boisson',
      'the',
      'cafe',
    ])) {
      return FoodCategory.beverages;
    }
    if (_containsAny(normalized, [
      'pain',
      'baguette',
      'croissant',
      'brioche',
      'viennoiserie',
    ])) {
      return FoodCategory.bakery;
    }
    if (_containsAny(normalized, [
      'pizza',
      'quiche',
      'lasagne',
      'plat prepare',
      'sandwich',
    ])) {
      return FoodCategory.preparedMeals;
    }
    if (_containsAny(normalized, [
      'tomate',
      'salade',
      'pomme',
      'banane',
      'fruit',
      'legume',
      'courgette',
      'carotte',
      'avocat',
    ])) {
      return FoodCategory.produce;
    }

    return FoodCategory.other;
  }
}

abstract final class FoodUnitHelper {
  static String suggestForName(
    String name, {
    bool hasMeasuredAmount = false,
    bool useCommonDefault = false,
  }) {
    final normalized = _normalizeProductName(name);

    if (_containsAny(normalized, ['jambon', 'bacon', 'pain de mie'])) {
      return 'tranche';
    }
    if (_containsAny(normalized, ['oeuf', 'oeufs'])) return 'unité';
    if (_containsAny(normalized, ['lait', 'jus', 'soupe liquide'])) return 'l';
    if (_containsAny(normalized, ['chips', 'biscuit', 'cereale'])) {
      return hasMeasuredAmount ? 'g' : 'paquet';
    }
    if (_containsAny(normalized, [
      'poivre',
      'sel',
      'paprika',
      'curry',
      'epice',
      'herbe',
    ])) {
      return hasMeasuredAmount ? 'g' : 'pot';
    }
    if ((hasMeasuredAmount || useCommonDefault) &&
        _containsAny(normalized, [
          'farine',
          'sucre',
          'pate',
          'riz',
          'fromage',
          'viande',
          'poisson',
        ])) {
      return 'g';
    }

    return 'unité';
  }

  static double defaultAmountFor(String unit) {
    return switch (MeasurementHelper.normalizeUnit(unit)) {
      'g' => 100,
      'kg' => 1,
      'ml' => 500,
      'cl' => 50,
      'l' => 1,
      _ => 1,
    };
  }
}

String _normalizeProductName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâä]'), 'a')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('œ', 'oe');
}

bool _containsAny(String value, List<String> terms) {
  return terms.any(value.contains);
}

/// Données de démo. Remplacer par un appel repository ou une base locale.
abstract final class FridgeMockDataSource {
  static List<FoodItem> fetchAll() {
    final today = _today;

    return [
      FoodItem(
        id: '1',
        name: 'Lait',
        emoji: '🥛',
        amount: 1,
        unit: 'l',
        expiryDate: today.add(const Duration(days: 3)),
        category: FoodCategory.dairy,
      ),
      FoodItem(
        id: '2',
        name: 'Tomates',
        emoji: '🍅',
        amount: 4,
        unit: 'unité',
        quantity: 4,
        expiryDate: today.add(const Duration(days: 1)),
        category: FoodCategory.produce,
      ),
      FoodItem(
        id: '3',
        name: 'Emmental',
        emoji: '🧀',
        amount: 200,
        unit: 'g',
        expiryDate: today.add(const Duration(days: 12)),
        category: FoodCategory.dairy,
      ),
      FoodItem(
        id: '4',
        name: 'Steak haché',
        emoji: '🥩',
        amount: 2,
        unit: 'unité',
        quantity: 2,
        expiryDate: today,
        category: FoodCategory.meat,
      ),
      FoodItem(
        id: '5',
        name: 'Œufs',
        emoji: '🥚',
        amount: 6,
        unit: 'unité',
        quantity: 6,
        expiryDate: today.add(const Duration(days: 6)),
        category: FoodCategory.dairy,
      ),
      FoodItem(
        id: '6',
        name: 'Yaourt nature',
        emoji: '🥣',
        amount: 4,
        unit: 'unité',
        quantity: 4,
        expiryDate: today.subtract(const Duration(days: 2)),
        category: FoodCategory.dairy,
      ),
    ];
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class FridgeStats {
  const FridgeStats({
    required this.total,
    required this.expiringSoon,
    required this.expired,
  });

  final int total;
  final int expiringSoon;
  final int expired;

  factory FridgeStats.fromItems(List<FoodItem> items) {
    var total = 0;
    var expiringSoon = 0;
    var expired = 0;

    for (final item in items) {
      final units = item.quantity;
      total += units;

      final days = ExpiryHelper.daysUntilExpiry(item.expiryDate);
      if (days < 0) {
        expired += units;
      } else if (days < 3) {
        expiringSoon += units;
      }
    }

    return FridgeStats(
      total: total,
      expiringSoon: expiringSoon,
      expired: expired,
    );
  }
}

abstract final class ExpiryHelper {
  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static int daysUntilExpiry(DateTime expiryDate) {
    final normalized = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    return normalized.difference(_today).inDays;
  }

  static bool isUrgentForReminder(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);
    return days >= 0 && days <= 1;
  }

  static ExpiryUrgency urgencyFor(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);
    if (days <= 0) return ExpiryUrgency.expired;
    if (days < 3) return ExpiryUrgency.warning;
    return ExpiryUrgency.safe;
  }

  static Color colorFor(ExpiryUrgency urgency) {
    return switch (urgency) {
      ExpiryUrgency.expired => AppColors.expired,
      ExpiryUrgency.warning => AppColors.expiringSoon,
      ExpiryUrgency.safe => AppColors.primary,
    };
  }

  static Color backgroundFor(ExpiryUrgency urgency) {
    return colorFor(urgency).withValues(alpha: 0.12);
  }

  static String labelFor(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);

    if (days < 0) {
      final overdue = days.abs();
      return overdue == 1 ? 'Expiré hier' : 'Expiré il y a $overdue jours';
    }
    if (days == 0) return 'Expire aujourd’hui';
    if (days == 1) return 'Expire demain';
    return 'Expire dans $days jours';
  }

  static IconData iconForCategory(FoodCategory category) {
    return FoodCategoryHelper.icon(category);
  }
}
