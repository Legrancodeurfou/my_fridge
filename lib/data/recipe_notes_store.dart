import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecipeNotesStore extends ChangeNotifier {
  RecipeNotesStore._(this._notesByRecipeName);

  static const _storageKey = 'recipe_notes';

  Map<String, String> _notesByRecipeName;

  Map<String, String> get notesByRecipeName =>
      Map.unmodifiable(_notesByRecipeName);

  static Future<RecipeNotesStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_storageKey);

    if (savedJson == null || savedJson.isEmpty) {
      return RecipeNotesStore._({});
    }

    try {
      final decoded = jsonDecode(savedJson) as Map<String, dynamic>;
      final notes = decoded.map(
        (key, value) => MapEntry(key, value.toString()),
      );

      return RecipeNotesStore._(notes);
    } catch (_) {
      return RecipeNotesStore._({});
    }
  }

  String noteFor(String recipeName) {
    return _notesByRecipeName[_keyFor(recipeName)] ?? '';
  }

  bool hasNoteFor(String recipeName) {
    return noteFor(recipeName).trim().isNotEmpty;
  }

  Future<void> updateNote(String recipeName, String note) async {
    final key = _keyFor(recipeName);
    final cleanedNote = note.trim();

    if (cleanedNote.isEmpty) {
      _notesByRecipeName = {..._notesByRecipeName}..remove(key);
    } else {
      _notesByRecipeName = {
        ..._notesByRecipeName,
        key: note,
      };
    }

    notifyListeners();
    await _save();
  }

  Future<void> deleteNote(String recipeName) async {
    final key = _keyFor(recipeName);
    if (!_notesByRecipeName.containsKey(key)) return;

    _notesByRecipeName = {..._notesByRecipeName}..remove(key);
    notifyListeners();
    await _save();
  }

  Future<void> replaceAllNotes(Map<String, String> notes) async {
    _notesByRecipeName = _normalizeNotes(notes);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_notesByRecipeName));
  }

  static String _keyFor(String recipeName) {
    return recipeName.trim().toLowerCase();
  }

  static Map<String, String> _normalizeNotes(Map<String, String> notes) {
    final result = <String, String>{};

    for (final entry in notes.entries) {
      final key = _keyFor(entry.key);
      if (key.isEmpty || entry.value.trim().isEmpty) continue;
      result[key] = entry.value;
    }

    return result;
  }
}
