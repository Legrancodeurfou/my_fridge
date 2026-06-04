import '../models/food.dart';
import 'supabase_service.dart';

/// Premier service cloud pour préparer la future synchro du frigo.
///
/// Il n'est pas encore branché aux stores locaux.
/// Objectif: avoir une couche Supabase prête sans casser le mode local actuel.
class CloudFoodsService {
  const CloudFoodsService();

  Future<List<FoodItem>> fetchFoods() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final rows = await SupabaseService.client
        .from('foods')
        .select()
        .eq('user_id', userId)
        .order('expiration_date');

    return [
      for (final row in rows as List<dynamic>)
        _foodFromRow(row as Map<String, dynamic>),
    ];
  }

  Future<void> upsertFood(FoodItem food) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await SupabaseService.client.from('foods').upsert(
      _foodToRow(food, userId: userId),
      onConflict: 'id',
    );
  }

  Future<void> deleteFood(String foodId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await SupabaseService.client
        .from('foods')
        .delete()
        .eq('id', foodId)
        .eq('user_id', userId);
  }

  Map<String, dynamic> _foodToRow(FoodItem food, {required String userId}) {
    return {
      'id': food.id,
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

  FoodItem _foodFromRow(Map<String, dynamic> row) {
    final categoryName = row['category'] as String? ?? FoodCategory.other.name;
    final category = FoodCategory.values.asNameMap()[categoryName] ??
        FoodCategory.other;

    final rawAmount = row['amount'];
    final amount = switch (rawAmount) {
      final int value => value.toDouble(),
      final double value => value,
      final num value => value.toDouble(),
      _ => 1.0,
    };

    final rawQuantity = row['quantity'];
    final quantity = switch (rawQuantity) {
      final int value => value,
      final num value => value.toInt(),
      _ => MeasurementHelper.logicalQuantity(amount, row['unit'] as String? ?? 'unité'),
    };

    return FoodItem(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Produit',
      emoji: row['emoji'] as String? ?? FoodCategoryHelper.emoji(category),
      category: category,
      quantity: quantity < 1 ? 1 : quantity,
      amount: amount <= 0 ? 1 : amount,
      unit: row['unit'] as String? ?? 'unité',
      expiryDate: DateTime.parse(row['expiration_date'] as String),
    );
  }

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
