import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

abstract final class CloudFavoriteRecipesService {
  static Future<void> uploadFavorites(List<String> favoriteNames) async {
    final user = _currentUser;

    final rows = _cleanNames(favoriteNames)
        .map((recipeName) => {'user_id': user.id, 'recipe_name': recipeName})
        .toList();

    await SupabaseService.client.rpc(
      'replace_user_favorite_recipes',
      params: {'p_items': rows},
    );
  }

  static Future<List<String>> downloadFavorites() async {
    final user = _currentUser;

    final rows = await SupabaseService.client
        .from('favorite_recipes')
        .select('recipe_name')
        .eq('user_id', user.id)
        .order('created_at', ascending: true);

    return _cleanNames(
      rows.map((row) => row['recipe_name']).whereType<String>().toList(),
    );
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

  static List<String> _cleanNames(List<String> names) {
    final seen = <String>{};
    final result = <String>[];

    for (final name in names) {
      final cleanName = name.trim();
      if (cleanName.isEmpty || seen.contains(cleanName)) continue;
      seen.add(cleanName);
      result.add(cleanName);
    }

    return result;
  }
}
