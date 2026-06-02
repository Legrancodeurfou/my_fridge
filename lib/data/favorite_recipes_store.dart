import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteRecipesStore extends ChangeNotifier {
  FavoriteRecipesStore._(this._favoriteNames);

  static const _storageKey = 'favorite_recipe_names';

  List<String> _favoriteNames;

  List<String> get favoriteNames => List.unmodifiable(_favoriteNames);

  int get count => _favoriteNames.length;

  bool isFavorite(String recipeName) {
    return _favoriteNames.contains(recipeName);
  }

  static Future<FavoriteRecipesStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNames = prefs.getStringList(_storageKey) ?? const <String>[];
    return FavoriteRecipesStore._(_deduplicate(savedNames));
  }

  Future<void> toggleFavorite(String recipeName) async {
    if (isFavorite(recipeName)) {
      _favoriteNames = _favoriteNames.where((name) => name != recipeName).toList();
    } else {
      _favoriteNames = [..._favoriteNames, recipeName];
    }

    notifyListeners();
    await _save();
  }

  Future<void> removeFavorite(String recipeName) async {
    if (!isFavorite(recipeName)) return;

    _favoriteNames = _favoriteNames.where((name) => name != recipeName).toList();
    notifyListeners();
    await _save();
  }

  Future<void> clearAll() async {
    if (_favoriteNames.isEmpty) return;

    _favoriteNames = [];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _favoriteNames);
  }

  static List<String> _deduplicate(List<String> names) {
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
