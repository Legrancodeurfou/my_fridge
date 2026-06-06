import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food.dart';
import 'supabase_service.dart';

abstract final class CloudFoodsService {
  static Future<void> uploadFoods(List<FoodItem> foods) async {
    final user = _currentUser;

    await SupabaseService.client
        .from('foods')
        .delete()
        .eq('user_id', user.id);

    if (foods.isEmpty) return;

    final rows = foods.map((food) => _toSupabaseRow(food, user.id)).toList();

    await SupabaseService.client.from('foods').insert(rows);
  }

  static Future<List<FoodItem>> downloadFoods() async {
    final user = _currentUser;

    final rows = await SupabaseService.client
        .from('foods')
        .select()
        .eq('user_id', user.id)
        .order('expiration_date', ascending: true);

    return rows
        .map<FoodItem>((row) => _fromSupabaseRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  static User get _currentUser {
    if (!SupabaseService.isInitialized) {
      throw Exception('Supabase n’est pas initialisé.');
    }

    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    return user;
  }

  static Map<String, dynamic> _toSupabaseRow(FoodItem food, String userId) {
    return {
      'user_id': userId,
      'name': food.name,
      'emoji': food.emoji,
      'category': food.category.name,
      'quantity': food.quantity,
      'amount': food.amount,
      'unit': food.unit,
      'expiration_date': _dateOnly(food.expiryDate),
    };
  }

  static FoodItem _fromSupabaseRow(Map<String, dynamic> row) {
    final amount = _positiveDouble(row['amount'], fallback: 1);

    return FoodItem(
      id: row['id'] as String,
      name: row['name'] as String,
      emoji: row['emoji'] as String? ?? '🍽️',
      category: _categoryFromName(row['category'] as String?),
      expiryDate: DateTime.parse(row['expiration_date'] as String),
      quantity: _positiveInt(row['quantity'], fallback: MeasurementHelper.logicalQuantity(amount, row['unit'] as String? ?? 'unité')),
      amount: amount,
      unit: row['unit'] as String? ?? 'unité',
    );
  }

  static FoodCategory _categoryFromName(String? value) {
    if (value == null) return FoodCategory.other;

    for (final category in FoodCategory.values) {
      if (category.name == value) return category;
    }

    return FoodCategory.other;
  }

  static int _positiveInt(dynamic value, {required int fallback}) {
    final parsed = switch (value) {
      final int number => number,
      final num number => number.toInt(),
      _ => fallback,
    };

    if (parsed < 1) return 1;
    if (parsed > 9999) return 9999;
    return parsed;
  }

  static double _positiveDouble(dynamic value, {required double fallback}) {
    final parsed = switch (value) {
      final double number => number,
      final int number => number.toDouble(),
      final num number => number.toDouble(),
      _ => fallback,
    };

    return parsed <= 0 ? fallback : parsed;
  }

  static String _dateOnly(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }
}
