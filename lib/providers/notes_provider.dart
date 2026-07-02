import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/note.dart';

/// Gère la liste des notes de l'utilisateur connecté : chargement,
/// création, mise à jour, suppression (avec possibilité d'annulation),
/// recherche et épinglage.
class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];
  String _searchQuery = '';
  bool _isLoading = false;

  Note? _lastDeleted;
  int? _lastDeletedIndex;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  List<Note> get notes {
    if (_searchQuery.trim().isEmpty) return _notes;
    final q = _searchQuery.toLowerCase();
    return _notes
        .where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q))
        .toList();
  }

  Future<void> loadNotes(int userId) async {
    _isLoading = true;
    notifyListeners();
    _notes = await DatabaseHelper.instance.getNotes(userId);
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addNote(Note note) async {
    final saved = await DatabaseHelper.instance.insertNote(note);
    _notes.insert(0, saved);
    _sort();
    notifyListeners();
  }

  Future<void> updateNote(Note note) async {
    final updated = note.copyWith(updatedAt: DateTime.now());
    await DatabaseHelper.instance.updateNote(updated);
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) _notes[idx] = updated;
    _sort();
    notifyListeners();
  }

  Future<void> togglePin(Note note) async {
    await updateNote(note.copyWith(pinned: !note.pinned));
  }

  /// Supprime une note tout en gardant une copie en mémoire pour
  /// permettre une annulation via un Snackbar ("Undo").
  Future<void> deleteNote(Note note) async {
    _lastDeletedIndex = _notes.indexWhere((n) => n.id == note.id);
    _lastDeleted = note;
    await DatabaseHelper.instance.deleteNote(note.id!);
    _notes.removeWhere((n) => n.id == note.id);
    notifyListeners();
  }

  Future<void> undoDelete() async {
    if (_lastDeleted == null) return;
    final restored = await DatabaseHelper.instance.insertNote(_lastDeleted!);
    final index = _lastDeletedIndex ?? 0;
    _notes.insert(index.clamp(0, _notes.length), restored);
    _lastDeleted = null;
    _lastDeletedIndex = null;
    _sort();
    notifyListeners();
  }

  void _sort() {
    _notes.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  void clear() {
    _notes = [];
    _searchQuery = '';
    notifyListeners();
  }
}
