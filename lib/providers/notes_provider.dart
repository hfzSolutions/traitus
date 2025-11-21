import 'package:flutter/foundation.dart';
import 'package:traitus/models/note.dart';
import 'package:traitus/models/note_section.dart';
import 'package:traitus/services/database_service.dart';

class NotesProvider with ChangeNotifier {
  NotesProvider() {
    _loadNotes();
  }

  final DatabaseService _dbService = DatabaseService();
  List<Note> _notes = [];
  bool _isLoading = false;
  String? _error;

  List<Note> get notes => List.unmodifiable(_notes);
  bool get hasNotes => _notes.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadNotes() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notes = await _dbService.fetchNotes();
      // Notes are already sorted by most recent first from the database
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading notes: $e');
      _notes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reload notes from database
  Future<void> refreshNotes() async {
    await _loadNotes();
  }

  Future<Note> addNote({
    required String title,
    required String content,
  }) async {
    try {
      final note = Note(
        title: title,
        content: content,
      );
      
      final createdNote = await _dbService.createNote(note);
      _notes.insert(0, createdNote); // Add to beginning (most recent first)
      notifyListeners();
      return createdNote;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding note: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _dbService.deleteNote(id);
      _notes.removeWhere((note) => note.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting note: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String content,
  }) async {
    try {
      final index = _notes.indexWhere((note) => note.id == id);
      if (index != -1) {
        final updatedNote = _notes[index].copyWith(
          title: title,
          content: content,
        );
        await _dbService.updateNote(updatedNote);
        _notes[index] = updatedNote;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating note: $e');
      notifyListeners();
      rethrow;
    }
  }

  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Add a section to an existing note
  Future<NoteSection> addSectionToNote({
    required String noteId,
    required String content,
  }) async {
    try {
      final section = NoteSection(
        noteId: noteId,
        content: content,
      );
      
      final createdSection = await _dbService.createNoteSection(section);
      notifyListeners();
      return createdSection;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding section to note: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch sections for a note
  Future<List<NoteSection>> fetchNoteSections(String noteId) async {
    try {
      return await _dbService.fetchNoteSections(noteId);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching note sections: $e');
      rethrow;
    }
  }

  /// Update a note section
  Future<void> updateNoteSection(NoteSection section) async {
    try {
      await _dbService.updateNoteSection(section);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating note section: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a note section
  Future<void> deleteNoteSection(String sectionId) async {
    try {
      await _dbService.deleteNoteSection(sectionId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting note section: $e');
      notifyListeners();
      rethrow;
    }
  }
}
