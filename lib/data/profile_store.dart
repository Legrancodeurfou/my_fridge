import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CookingLevel { beginner, intermediate, advanced }

extension CookingLevelLabel on CookingLevel {
  String get label {
    return switch (this) {
      CookingLevel.beginner => 'Débutant',
      CookingLevel.intermediate => 'Intermédiaire',
      CookingLevel.advanced => 'Confirmé',
    };
  }

  static CookingLevel fromLabel(String value) {
    return CookingLevel.values.firstWhere(
      (level) => level.label == value,
      orElse: () => CookingLevel.intermediate,
    );
  }
}

enum ProfileGoal { saveMoney, eatHealthy, reduceWaste, saveTime }

extension ProfileGoalLabel on ProfileGoal {
  String get label {
    return switch (this) {
      ProfileGoal.saveMoney => 'Économiser',
      ProfileGoal.eatHealthy => 'Manger plus sain',
      ProfileGoal.reduceWaste => 'Réduire le gaspillage',
      ProfileGoal.saveTime => 'Gagner du temps',
    };
  }

  static ProfileGoal fromLabel(String value) {
    return ProfileGoal.values.firstWhere(
      (goal) => goal.label == value,
      orElse: () => ProfileGoal.reduceWaste,
    );
  }
}

class ProfileData {
  const ProfileData({
    required this.name,
    required this.cookingLevel,
    required this.goal,
    required this.hasAirfryer,
    required this.hasOven,
    required this.hasMicrowave,
    required this.hasThermomix,
  });

  final String name;
  final CookingLevel cookingLevel;
  final ProfileGoal goal;
  final bool hasAirfryer;
  final bool hasOven;
  final bool hasMicrowave;
  final bool hasThermomix;

  ProfileData copyWith({
    String? name,
    CookingLevel? cookingLevel,
    ProfileGoal? goal,
    bool? hasAirfryer,
    bool? hasOven,
    bool? hasMicrowave,
    bool? hasThermomix,
  }) {
    return ProfileData(
      name: name ?? this.name,
      cookingLevel: cookingLevel ?? this.cookingLevel,
      goal: goal ?? this.goal,
      hasAirfryer: hasAirfryer ?? this.hasAirfryer,
      hasOven: hasOven ?? this.hasOven,
      hasMicrowave: hasMicrowave ?? this.hasMicrowave,
      hasThermomix: hasThermomix ?? this.hasThermomix,
    );
  }

  static const defaults = ProfileData(
    name: 'Esteban',
    cookingLevel: CookingLevel.intermediate,
    goal: ProfileGoal.reduceWaste,
    hasAirfryer: false,
    hasOven: true,
    hasMicrowave: true,
    hasThermomix: false,
  );
}

class ProfileStore extends ChangeNotifier {
  ProfileStore._(
    this._profile,
    this._expiryRemindersEnabled,
    this._lastAppOpenedAt,
  );

  static const _nameKey = 'profile_name';
  static const _levelKey = 'profile_cooking_level';
  static const _goalKey = 'profile_goal';
  static const _airfryerKey = 'profile_airfryer';
  static const _ovenKey = 'profile_oven';
  static const _microwaveKey = 'profile_microwave';
  static const _thermomixKey = 'profile_thermomix';
  static const _expiryRemindersEnabledKey = 'profile_expiry_reminders_enabled';
  static const _lastAppOpenedAtKey = 'profile_last_app_opened_at';

  ProfileData _profile;
  bool _expiryRemindersEnabled;
  DateTime? _lastAppOpenedAt;

  ProfileData get profile => _profile;
  bool get expiryRemindersEnabled => _expiryRemindersEnabled;
  DateTime? get lastAppOpenedAt => _lastAppOpenedAt;

  static Future<ProfileStore> load() async {
    final prefs = await SharedPreferences.getInstance();

    final store = ProfileStore._(
      ProfileData(
        name: prefs.getString(_nameKey) ?? ProfileData.defaults.name,
        cookingLevel: CookingLevelLabel.fromLabel(
          prefs.getString(_levelKey) ?? ProfileData.defaults.cookingLevel.label,
        ),
        goal: ProfileGoalLabel.fromLabel(
          prefs.getString(_goalKey) ?? ProfileData.defaults.goal.label,
        ),
        hasAirfryer: prefs.getBool(_airfryerKey) ?? ProfileData.defaults.hasAirfryer,
        hasOven: prefs.getBool(_ovenKey) ?? ProfileData.defaults.hasOven,
        hasMicrowave: prefs.getBool(_microwaveKey) ?? ProfileData.defaults.hasMicrowave,
        hasThermomix: prefs.getBool(_thermomixKey) ?? ProfileData.defaults.hasThermomix,
      ),
      prefs.getBool(_expiryRemindersEnabledKey) ?? false,
      DateTime.tryParse(
        prefs.getString(_lastAppOpenedAtKey) ?? '',
      ),
    );

    await store.recordAppOpened();
    return store;
  }

  Future<void> updateExpiryRemindersEnabled(bool value) async {
    _expiryRemindersEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expiryRemindersEnabledKey, value);
  }

  Future<void> recordAppOpened() async {
    _lastAppOpenedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastAppOpenedAtKey,
      _lastAppOpenedAt!.toIso8601String(),
    );
  }

  Future<void> updateName(String value) async {
    _profile = _profile.copyWith(name: value.trim().isEmpty ? 'Esteban' : value.trim());
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _profile.name);
  }

  Future<void> updateCookingLevel(CookingLevel value) async {
    _profile = _profile.copyWith(cookingLevel: value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_levelKey, value.label);
  }

  Future<void> updateGoal(ProfileGoal value) async {
    _profile = _profile.copyWith(goal: value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalKey, value.label);
  }

  Future<void> updateAirfryer(bool value) async {
    _profile = _profile.copyWith(hasAirfryer: value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_airfryerKey, value);
  }

  Future<void> updateOven(bool value) async {
    _profile = _profile.copyWith(hasOven: value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ovenKey, value);
  }

  Future<void> updateMicrowave(bool value) async {
    _profile = _profile.copyWith(hasMicrowave: value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_microwaveKey, value);
  }

  Future<void> updateThermomix(bool value) async {
    _profile = _profile.copyWith(hasThermomix: value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_thermomixKey, value);
  }
}
