import 'package:flutter/material.dart';

enum ExpiryUrgency { expired, warning, safe }

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.expiryDate,
    this.category = FoodCategory.other,
    this.quantity = 1,
    this.amount = 1,
    this.unit = 'unité',
  })  : assert(quantity >= 1),
        assert(amount > 0);

  final String id;
  final String name;
  final String emoji;
  final DateTime expiryDate;
  final FoodCategory category;

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
      final num value => value.toDouble(),
      _ => (quantity < 1 ? 1 : quantity).toDouble(),
    };

    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      category: FoodCategory.values.byName(json['category'] as String),
      quantity: quantity < 1 ? 1 : quantity,
      amount: amount <= 0 ? 1 : amount,
      unit: json['unit'] as String? ?? 'unité',
    );
  }
}

abstract final class MeasurementHelper {
  static const units = ['g', 'kg', 'ml', 'cl', 'l', 'unité', 'tranche'];

  static String label(double amount, String unit) {
    final formattedAmount = inputValue(amount);
    final displayUnit = _pluralize(unit, amount);
    return '$formattedAmount $displayUnit';
  }

  static String inputValue(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }
    return amount.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  static double stepFor(String unit) {
    return switch (unit) {
      'g' => 50,
      'kg' => 0.1,
      'ml' => 50,
      'cl' => 5,
      'l' => 0.5,
      'tranche' => 1,
      'unité' => 1,
      _ => 1,
    };
  }

  static int logicalQuantity(double amount, String unit) {
    if (unit == 'unité' || unit == 'tranche') {
      return amount.round().clamp(1, 9999);
    }
    return 1;
  }

  static String _pluralize(String unit, double amount) {
    if (amount <= 1) return unit;
    return switch (unit) {
      'unité' => 'unités',
      'tranche' => 'tranches',
      _ => unit,
    };
  }
}

enum FoodCategory { dairy, produce, meat, other }

abstract final class FoodCategoryHelper {
  static String label(FoodCategory category) {
    return switch (category) {
      FoodCategory.dairy => 'Produits laitiers',
      FoodCategory.produce => 'Fruits & légumes',
      FoodCategory.meat => 'Viande & poisson',
      FoodCategory.other => 'Autre',
    };
  }

  static String emoji(FoodCategory category) {
    return switch (category) {
      FoodCategory.dairy => '🥛',
      FoodCategory.produce => '🥬',
      FoodCategory.meat => '🥩',
      FoodCategory.other => '🍽️',
    };
  }
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
    final normalized =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return normalized.difference(_today).inDays;
  }

  static ExpiryUrgency urgencyFor(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);
    if (days <= 0) return ExpiryUrgency.expired;
    if (days < 3) return ExpiryUrgency.warning;
    return ExpiryUrgency.safe;
  }

  static Color colorFor(ExpiryUrgency urgency) {
    return switch (urgency) {
      ExpiryUrgency.expired => const Color(0xFFE53935),
      ExpiryUrgency.warning => const Color(0xFFFB8C00),
      ExpiryUrgency.safe => const Color(0xFF43A047),
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
    return switch (category) {
      FoodCategory.dairy => Icons.egg_alt_outlined,
      FoodCategory.produce => Icons.eco_outlined,
      FoodCategory.meat => Icons.set_meal_outlined,
      FoodCategory.other => Icons.restaurant_outlined,
    };
  }
}
