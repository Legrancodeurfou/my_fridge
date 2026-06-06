import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/scan_history_item.dart';
import 'supabase_service.dart';

abstract final class CloudScanHistoryService {
  static Future<void> uploadItems(List<ScanHistoryItem> items) async {
    final user = _currentUser;
    final rows = items.map((item) => _toSupabaseRow(item, user.id)).toList();

    await SupabaseService.client.rpc(
      'replace_user_scan_history',
      params: {'p_items': rows},
    );
  }

  static Future<List<ScanHistoryItem>> downloadItems() async {
    final user = _currentUser;

    final rows = await SupabaseService.client
        .from('scan_history')
        .select()
        .eq('user_id', user.id)
        .order('scanned_at', ascending: false);

    return rows
        .map<ScanHistoryItem>(
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

  static Map<String, dynamic> _toSupabaseRow(
    ScanHistoryItem item,
    String userId,
  ) {
    return {
      'user_id': userId,
      'scanned_at': item.scannedAt.toIso8601String(),
      'detected_count': item.detectedCount,
      'validated_count': item.validatedCount,
      'source': item.source,
      'status': item.usedFallback ? 'fallback' : 'success',
      'model': item.model,
      'products': item.products.map((product) => product.toJson()).toList(),
    };
  }

  static ScanHistoryItem _fromSupabaseRow(Map<String, dynamic> row) {
    final rawProducts = row['products'];
    final products = rawProducts is List
        ? rawProducts
              .whereType<Map>()
              .map(
                (product) => ScanHistoryProduct.fromJson(
                  Map<String, dynamic>.from(product),
                ),
              )
              .toList()
        : <ScanHistoryProduct>[];

    return ScanHistoryItem(
      id: row['id'] as String,
      scannedAt:
          DateTime.tryParse(row['scanned_at'] as String? ?? '') ??
          DateTime.now(),
      detectedCount: _nonNegativeInt(
        row['detected_count'],
        fallback: products.length,
      ),
      validatedCount: _nonNegativeInt(
        row['validated_count'],
        fallback: products.length,
      ),
      products: products,
      source: row['source'] as String? ?? 'unknown',
      model: row['model'] as String?,
    );
  }

  static int _nonNegativeInt(dynamic value, {required int fallback}) {
    final parsed = switch (value) {
      final int number => number,
      final num number => number.toInt(),
      _ => fallback,
    };

    return parsed < 0 ? fallback : parsed;
  }
}
