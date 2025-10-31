import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traitus/models/note.dart';

class NotesProvider with ChangeNotifier {
  List<Note> _notes = [];
  static const String _storageKey = 'saved_notes';

  List<Note> get notes => List.unmodifiable(_notes);

  bool get hasNotes => _notes.isNotEmpty;

  NotesProvider() {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString(_storageKey);
      if (notesJson != null) {
        final List<dynamic> decoded = jsonDecode(notesJson);
        _notes = decoded.map((json) => Note.fromJson(json)).toList();
        // Sort by most recent first
        _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
  }

  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = jsonEncode(_notes.map((note) => note.toJson()).toList());
      await prefs.setString(_storageKey, notesJson);
    } catch (e) {
      debugPrint('Error saving notes: $e');
    }
  }

  Future<void> addNote({
    required String title,
    required String content,
  }) async {
    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
    );
    _notes.insert(0, note); // Add to beginning (most recent first)
    notifyListeners();
    await _saveNotes();
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
    await _saveNotes();
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String content,
  }) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        title: title,
        content: content,
      );
      notifyListeners();
      await _saveNotes();
    }
  }

  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }
}

