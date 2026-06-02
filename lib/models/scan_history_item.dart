import 'food.dart';

class ScanHistoryProduct {
  const ScanHistoryProduct({
    required this.name,
    required this.amount,
    required this.unit,
  }) : assert(amount > 0);

  final String name;
  final double amount;
  final String unit;

  String get amountLabel => MeasurementHelper.label(amount, unit);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }

  factory ScanHistoryProduct.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = switch (rawAmount) {
      final int value => value.toDouble(),
      final double value => value,
      final num value => value.toDouble(),
      _ => 1.0,
    };

    return ScanHistoryProduct(
      name: json['name'] as String? ?? 'Produit',
      amount: amount <= 0 ? 1 : amount,
      unit: json['unit'] as String? ?? 'unité',
    );
  }

  factory ScanHistoryProduct.fromFood(FoodItem food) {
    return ScanHistoryProduct(
      name: food.name,
      amount: food.amount,
      unit: food.unit,
    );
  }
}

class ScanHistoryItem {
  const ScanHistoryItem({
    required this.id,
    required this.scannedAt,
    required this.detectedCount,
    required this.validatedCount,
    required this.products,
  });

  final String id;
  final DateTime scannedAt;
  final int detectedCount;
  final int validatedCount;
  final List<ScanHistoryProduct> products;

  String get summary {
    if (products.isEmpty) return 'Aucun produit ajouté';
    final names = products.take(3).map((product) => product.name).join(', ');
    final remaining = products.length - 3;
    return remaining > 0 ? '$names +$remaining' : names;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scannedAt': scannedAt.toIso8601String(),
      'detectedCount': detectedCount,
      'validatedCount': validatedCount,
      'products': products.map((product) => product.toJson()).toList(),
    };
  }

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final products = rawProducts is List
        ? rawProducts
            .map((item) => ScanHistoryProduct.fromJson(item as Map<String, dynamic>))
            .toList()
        : <ScanHistoryProduct>[];

    return ScanHistoryItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      scannedAt: DateTime.tryParse(json['scannedAt'] as String? ?? '') ?? DateTime.now(),
      detectedCount: (json['detectedCount'] as num?)?.toInt() ?? products.length,
      validatedCount: (json['validatedCount'] as num?)?.toInt() ?? products.length,
      products: products,
    );
  }
}
