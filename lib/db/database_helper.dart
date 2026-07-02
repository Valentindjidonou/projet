import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/note.dart';
import '../models/user.dart';

/// Point d'accès unique (singleton) à la base de données SQLite locale.
/// Deux tables : `users` (authentification) et `notes` (contenu utilisateur).
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;
  static bool _ffiInitialized = false;

  /// Le plugin `sqflite` ne fournit une implémentation native que pour
  /// Android et iOS. Sur Linux, Windows et macOS (et en tests), il faut
  /// utiliser `sqflite_common_ffi`, qui s'appuie sur la librairie SQLite
  /// du système. Sans cette bascule, toute requête échoue silencieusement
  /// sur desktop et la connexion / l'inscription semblent "refusées".
  void _ensureFactory() {
    if (_ffiInitialized || kIsWeb) return;
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialized = true;
  }

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    _ensureFactory();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mes_notes.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        passwordHash TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Autre',
        pinned INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Compte de démonstration pré-rempli : Daniel / password123
    // (le mot de passe est haché, jamais stocké en clair).
    await db.insert('users', {
      'username': 'Daniel',
      'passwordHash': hashPassword('password123'),
    });
  }

  static String hashPassword(String plain) {
    final bytes = utf8.encode(plain);
    return sha256.convert(bytes).toString();
  }

  // ---------------- Utilisateurs ----------------

  Future<AppUser?> getUserByUsername(String username) async {
    final db = await database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  /// Retourne l'utilisateur si les identifiants sont corrects, sinon null.
  Future<AppUser?> authenticate(String username, String password) async {
    final user = await getUserByUsername(username);
    if (user == null) return null;
    if (user.passwordHash == hashPassword(password)) return user;
    return null;
  }

  /// Crée un nouveau compte. Lève une exception si le nom existe déjà.
  Future<AppUser> createUser(String username, String password) async {
    final db = await database;
    final id = await db.insert('users', {
      'username': username,
      'passwordHash': hashPassword(password),
    });
    return AppUser(id: id, username: username, passwordHash: hashPassword(password));
  }

  // ---------------- Notes ----------------

  Future<List<Note>> getNotes(int userId) async {
    final db = await database;
    final rows = await db.query(
      'notes',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'pinned DESC, updatedAt DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<Note> insertNote(Note note) async {
    final db = await database;
    final id = await db.insert('notes', note.toMap());
    return note.copyWith(id: id);
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
