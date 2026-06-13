import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  static const _androidAuthRedirectUrl = 'com.myfridge.app://login-callback';

  AuthService() {
    _initialize();
  }

  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  bool _isBusy = false;
  bool _isCloudOnboardingPending = false;
  bool _shouldShowCloudOnboarding = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isBusy => _isBusy;
  bool get isSignedIn => _user != null;
  bool get isAvailable => SupabaseService.isInitialized;
  bool get isCloudOnboardingPending => _isCloudOnboardingPending;
  bool get shouldShowCloudOnboarding => _shouldShowCloudOnboarding;
  String? get email => _user?.email;
  String? get userId => _user?.id;
  String? get displayName {
    final metadata = _user?.userMetadata;
    if (metadata == null) return null;

    for (final key in const ['full_name', 'name', 'display_name']) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }

    return null;
  }

  String? get errorMessage => _errorMessage;

  void _initialize() {
    if (!SupabaseService.isInitialized) return;

    _user = SupabaseService.client.auth.currentUser;
    _isCloudOnboardingPending = _user != null;
    _shouldShowCloudOnboarding = false;

    if (_user != null) {
      unawaited(_upsertCloudUser());
      unawaited(_loadCloudOnboardingState(_user!));
    }

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((
      authState,
    ) async {
      final previousUserId = _user?.id;
      final nextUser = authState.session?.user;

      _user = nextUser;
      _errorMessage = null;

      if (nextUser == null) {
        _isCloudOnboardingPending = false;
        _shouldShowCloudOnboarding = false;
      } else if (previousUserId != nextUser.id) {
        _isCloudOnboardingPending = true;
        _shouldShowCloudOnboarding = false;
      }

      notifyListeners();

      if (nextUser != null) {
        await _loadCloudOnboardingState(nextUser);
        await _upsertCloudUser();
      }
    });
  }

  Future<void> completeCloudOnboarding() async {
    if (!_isCloudOnboardingPending) return;
    _isCloudOnboardingPending = false;
    _shouldShowCloudOnboarding = false;
    notifyListeners();

    final currentUserId = userId;
    if (currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudOnboardingCompletedKey(currentUserId), true);
    await prefs.setBool(_cloudPromptDismissedKey(currentUserId), true);
  }

  Future<void> dismissCloudOnboardingPrompt() async {
    if (!_isCloudOnboardingPending) return;
    _shouldShowCloudOnboarding = false;
    notifyListeners();

    final currentUserId = userId;
    if (currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudPromptDismissedKey(currentUserId), true);
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
        redirectTo: kIsWeb
            ? Uri.base.origin
            : defaultTargetPlatform == TargetPlatform.android
            ? _androidAuthRedirectUrl
            : null,
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
      _isCloudOnboardingPending = false;
      _shouldShowCloudOnboarding = false;
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
      await SupabaseService.client.from('users').upsert({
        'id': currentUser.id,
        'email': currentUser.email,
      }, onConflict: 'id');
    } catch (error) {
      _errorMessage = 'Profil cloud non synchronisé : $error';
      notifyListeners();
    }
  }

  Future<void> _loadCloudOnboardingState(User currentUser) async {
    final prefs = await SharedPreferences.getInstance();
    if (_user?.id != currentUser.id) return;

    final completed =
        prefs.getBool(_cloudOnboardingCompletedKey(currentUser.id)) ?? false;
    final dismissed =
        prefs.getBool(_cloudPromptDismissedKey(currentUser.id)) ?? false;

    _isCloudOnboardingPending = !completed;
    _shouldShowCloudOnboarding = !completed && !dismissed;
    notifyListeners();
  }

  static String _cloudOnboardingCompletedKey(String userId) {
    return 'cloud_onboarding_completed_$userId';
  }

  static String _cloudPromptDismissedKey(String userId) {
    return 'cloud_prompt_dismissed_$userId';
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
