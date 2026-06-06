import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shopping_item.dart';
import 'supabase_service.dart';

abstract final class CloudShoppingListService {
  static Future<void> uploadItems(List<ShoppingItem> items) async {
    final user = _currentUser;

    await SupabaseService.client
        .from('shopping_items')
        .delete()
        .eq('user_id', user.id);

    if (items.isEmpty) return;

    final rows = items.map((item) => _toSupabaseRow(item, user.id)).toList();

    await SupabaseService.client.from('shopping_items').insert(rows);
  }

  static Future<List<ShoppingItem>> downloadItems() async {
    final user = _currentUser;

    final rows = await SupabaseService.client
        .from('shopping_items')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: true);

    return rows
        .map<ShoppingItem>(
          (row) => _fromSupabaseRow(Map<String, dynamic>.from(row)),
        )
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

  static Map<String, dynamic> _toSupabaseRow(ShoppingItem item, String userId) {
    return {
      'user_id': userId,
      'name': item.name,
      'amount': item.amount,
      'unit': item.unit,
      'is_checked': item.isChecked,
    };
  }

  static ShoppingItem _fromSupabaseRow(Map<String, dynamic> row) {
    return ShoppingItem(
      id: row['id'] as String,
      name: row['name'] as String,
      amount: _positiveDouble(row['amount'], fallback: 1),
      unit: row['unit'] as String? ?? 'unité',
      isChecked: row['is_checked'] as bool? ?? false,
    );
  }

  static double _positiveDouble(dynamic value, {required double fallback}) {
    final parsed = switch (value) {
      final double number => number,
      final int number => number.toDouble(),
      _ => fallback,
    };

    return parsed <= 0 ? fallback : parsed;
  }
}
