import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

abstract final class CloudRecipeNotesService {
  static Future<void> uploadNotes(Map<String, String> notes) async {
    final user = _currentUser;

    final rows = _cleanNotes(notes).entries
        .map(
          (entry) => {
            'user_id': user.id,
            'recipe_name': entry.key,
            'note': entry.value,
          },
        )
        .toList();

    await SupabaseService.client.rpc(
      'replace_user_recipe_notes',
      params: {'p_items': rows},
    );
  }

  static Future<Map<String, String>> downloadNotes() async {
    final user = _currentUser;

    final rows = await SupabaseService.client
        .from('recipe_notes')
        .select('recipe_name, note')
        .eq('user_id', user.id)
        .order('created_at', ascending: true);

    return _cleanNotes({
      for (final row in rows)
        if (row['recipe_name'] is String && row['note'] is String)
          row['recipe_name'] as String: row['note'] as String,
    });
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

  static Map<String, String> _cleanNotes(Map<String, String> notes) {
    final result = <String, String>{};

    for (final entry in notes.entries) {
      final recipeName = entry.key.trim().toLowerCase();
      if (recipeName.isEmpty || entry.value.trim().isEmpty) continue;
      result[recipeName] = entry.value;
    }

    return result;
  }
}
