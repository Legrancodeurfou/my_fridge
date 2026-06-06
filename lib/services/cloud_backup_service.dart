import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class CloudBackup {
  const CloudBackup({
    required this.id,
    required this.createdAt,
    required this.reason,
  });

  final String id;
  final DateTime createdAt;
  final String reason;

  factory CloudBackup.fromRow(Map<String, dynamic> row) {
    return CloudBackup(
      id: row['id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      reason: row['reason'] as String? ?? 'Sauvegarde cloud',
    );
  }
}

abstract final class CloudBackupService {
  static const _maxBackups = 3;

  static Future<CloudBackup> createBackup(
    String reason, {
    String? preserveBackupId,
  }) async {
    final user = _currentUser;

    final foodsFuture = SupabaseService.client
        .from('foods')
        .select(
          'name, emoji, category, quantity, amount, unit, expiration_date',
        )
        .eq('user_id', user.id);
    final shoppingItemsFuture = SupabaseService.client
        .from('shopping_items')
        .select('name, amount, unit, is_checked')
        .eq('user_id', user.id);
    final scanHistoryFuture = SupabaseService.client
        .from('scan_history')
        .select(
          'scanned_at, detected_count, validated_count, source, status, model, products',
        )
        .eq('user_id', user.id);
    final favoriteRecipesFuture = SupabaseService.client
        .from('favorite_recipes')
        .select('recipe_name')
        .eq('user_id', user.id);
    final recipeNotesFuture = SupabaseService.client
        .from('recipe_notes')
        .select('recipe_name, note')
        .eq('user_id', user.id);

    final foods = await foodsFuture;
    final shoppingItems = await shoppingItemsFuture;
    final scanHistory = await scanHistoryFuture;
    final favoriteRecipes = await favoriteRecipesFuture;
    final recipeNotes = await recipeNotesFuture;

    final row = await SupabaseService.client
        .from('cloud_backups')
        .insert({
          'user_id': user.id,
          'reason': _cleanReason(reason),
          'payload': {
            'foods': foods,
            'shopping_items': shoppingItems,
            'scan_history': scanHistory,
            'favorite_recipes': favoriteRecipes,
            'recipe_notes': recipeNotes,
          },
        })
        .select('id, created_at, reason')
        .single();

    await deleteOldBackupsKeepingLatest3(
      preserveBackupId: preserveBackupId,
    );

    return CloudBackup.fromRow(Map<String, dynamic>.from(row));
  }

  static Future<List<CloudBackup>> listBackups() async {
    final user = _currentUser;

    final rows = await SupabaseService.client
        .from('cloud_backups')
        .select('id, created_at, reason')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(_maxBackups);

    return rows
        .map<CloudBackup>(
          (row) => CloudBackup.fromRow(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<void> restoreBackup(String backupId) async {
    final user = _currentUser;

    final row = await SupabaseService.client
        .from('cloud_backups')
        .select('payload')
        .eq('id', backupId)
        .eq('user_id', user.id)
        .single();

    _validatePayload(row['payload']);

    await SupabaseService.client.rpc(
      'restore_cloud_backup',
      params: {'p_backup_id': backupId},
    );
  }

  static Future<void> deleteOldBackupsKeepingLatest3({
    String? preserveBackupId,
  }) async {
    final user = _currentUser;

    final rows = await SupabaseService.client
        .from('cloud_backups')
        .select('id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final backupIds = rows.map((row) => row['id'] as String).toList();
    final keptIds = backupIds.take(_maxBackups).toSet();

    if (preserveBackupId != null &&
        backupIds.contains(preserveBackupId) &&
        !keptIds.contains(preserveBackupId)) {
      keptIds
        ..remove(backupIds[_maxBackups - 1])
        ..add(preserveBackupId);
    }

    for (final backupId in backupIds.where((id) => !keptIds.contains(id))) {
      await SupabaseService.client
          .from('cloud_backups')
          .delete()
          .eq('id', backupId)
          .eq('user_id', user.id);
    }
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

  static String _cleanReason(String reason) {
    final cleaned = reason.trim();
    return cleaned.isEmpty ? 'Sauvegarde manuelle' : cleaned;
  }

  static void _validatePayload(dynamic payload) {
    if (payload is! Map) {
      throw const FormatException('Payload de sauvegarde invalide.');
    }

    const requiredKeys = {
      'foods',
      'shopping_items',
      'scan_history',
      'favorite_recipes',
      'recipe_notes',
    };

    for (final key in requiredKeys) {
      if (payload[key] is! List) {
        throw FormatException('Données de sauvegarde invalides : $key.');
      }
    }
  }
}
