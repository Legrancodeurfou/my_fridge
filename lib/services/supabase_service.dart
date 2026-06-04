import 'package:supabase_flutter/supabase_flutter.dart';

/// Point d'entrée unique pour Supabase.
///
/// Les valeurs sont lues au build avec --dart-define :
/// - SUPABASE_URL
/// - SUPABASE_ANON_KEY
///
/// Si elles ne sont pas configurées, l'app continue de fonctionner en local.
/// Cela permet de préparer le cloud sans casser le MVP actuel.
abstract final class SupabaseService {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _initialized = false;

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  static bool get isInitialized => _initialized;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured || _initialized) return;

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _initialized = true;
    } catch (_) {
      // On ne bloque pas le MVP local si Supabase est mal configuré.
      _initialized = false;
    }
  }
}
