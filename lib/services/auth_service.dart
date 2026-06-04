import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  bool _isBusy = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isBusy => _isBusy;
  bool get isSignedIn => _user != null;
  bool get isAvailable => SupabaseService.isInitialized;
  String? get email => _user?.email;
  String? get userId => _user?.id;
  String? get errorMessage => _errorMessage;

  static Future<AuthService> load() async {
    final service = AuthService._();
    await service._initialize();
    return service;
  }

  Future<void> _initialize() async {
    if (!SupabaseService.isInitialized) return;

    _user = SupabaseService.client.auth.currentUser;
    if (_user != null) {
      await _upsertCloudUser();
    }

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (authState) async {
        _user = authState.session?.user;
        _errorMessage = null;

        if (_user != null) {
          await _upsertCloudUser();
        }

        notifyListeners();
      },
    );
  }

  Future<void> signInWithGoogle() async {
    if (!SupabaseService.isInitialized) {
      _errorMessage = 'Supabase n’est pas configuré sur cette version.';
      notifyListeners();
      return;
    }

    _setBusy(true);

    try {
      _errorMessage = null;

      await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
    } catch (error) {
      _errorMessage = 'Connexion Google impossible : $error';
      notifyListeners();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    if (!SupabaseService.isInitialized) return;

    _setBusy(true);

    try {
      await SupabaseService.client.auth.signOut();
      _user = null;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Déconnexion impossible : $error';
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _upsertCloudUser() async {
    final currentUser = _user;
    if (currentUser == null || !SupabaseService.isInitialized) return;

    try {
      await SupabaseService.client.from('users').upsert(
        {
          'id': currentUser.id,
          'email': currentUser.email,
        },
        onConflict: 'id',
      );
    } catch (error) {
      _errorMessage = 'Profil cloud non synchronisé : $error';
    }
  }

  void _setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
