import 'food.dart';

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    this.isChecked = false,
  }) : assert(amount > 0);

  final String id;
  final String name;
  final double amount;
  final String unit;
  final bool isChecked;

  String get amountLabel => MeasurementHelper.label(amount, unit);

  ShoppingItem copyWith({
    String? id,
    String? name,
    double? amount,
    String? unit,
    bool? isChecked,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'unit': unit,
      'isChecked': isChecked,
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];

    final amount = switch (rawAmount) {
      final int value => value.toDouble(),
      final double value => value,
      final num value => value.toDouble(),
      _ => 1.0,
    };

    return ShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: amount <= 0 ? 1 : amount,
      unit: json['unit'] as String? ?? 'unité',
      isChecked: json['isChecked'] as bool? ?? false,
    );
  }
}