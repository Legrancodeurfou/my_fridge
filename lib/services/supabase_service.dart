import 'package:supabase_flutter/supabase_flutter.dart';

/// Service central Supabase.
///
/// IMPORTANT MVP:
/// - Ne mets jamais la service_role key dans Flutter.
/// - Utilise uniquement la anon public key côté app.
/// - Les vraies protections sont dans Supabase avec les RLS policies.
class SupabaseService {
  const SupabaseService._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static String? get currentUserId => client.auth.currentUser?.id;

  static String? get currentUserEmail => client.auth.currentUser?.email;
}
