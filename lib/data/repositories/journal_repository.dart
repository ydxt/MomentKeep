import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';
import 'package:moment_keep/core/utils/encryption_helper.dart';
import 'package:moment_keep/services/database_service.dart';

/// Journal Repository
/// Manages local SQLite (encrypted) and Supabase data access and sync
class JournalRepository {
  /// Singleton instance
  static final JournalRepository _instance = JournalRepository._internal();

  /// Database service
  final DatabaseService _databaseService = DatabaseService();

  /// Supabase service
  final SupabaseService _supabase = SupabaseService();

  /// Sync manager
  final SupabaseSyncManager _syncManager = SupabaseSyncManager();

  /// Table name
  static const String _tableName = 'journals';

  /// Private constructor
  JournalRepository._internal();

  /// Factory constructor
  factory JournalRepository() => _instance;

  /// Get all journals
  Future<List<Journal>> getAll() async {
    try {
      final journals = await _queryLocal();
      _log('Retrieved ${journals.length} journals');
      return journals;
    } catch (e) {
      _log('Failed to get all journals: $e');
      return [];
    }
  }

  /// Get journal by ID
  Future<Journal?> getById(String id) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        _log('Journal not found: $id');
        return null;
      }

      final journal = await _decryptAndParseJournal(maps.first);
      _log('Get journal: $id');
      return journal;
    } catch (e) {
      _log('Failed to get journal: $e');
      return null;
    }
  }

  /// Insert a journal
  Future<String> insert(Journal item) async {
    try {
      final db = await _databaseService.database;
      final encryptedData = await _encryptJournal(item);

      await db.insert(
        _tableName,
        encryptedData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _log('Insert journal: ${item.id}');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'journals',
              id: item.id,
              type: SyncOperationType.insert,
              data: item.toJson(),
              timestamp: DateTime.now(),
            ),
          );
          _log('Journal queued for Supabase: ${item.id}');
        } catch (e) {
          _log('Failed to queue journal to Supabase: $e');
        }
      }

      return item.id;
    } catch (e) {
      _log('Failed to insert journal: $e');
      rethrow;
    }
  }

  /// Update a journal
  Future<void> update(String id, Journal item) async {
    try {
      final db = await _databaseService.database;
      final encryptedData = await _encryptJournal(item);

      await db.update(
        _tableName,
        encryptedData,
        where: 'id = ?',
        whereArgs: [id],
      );
      _log('Update journal: $id');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'journals',
              id: id,
              type: SyncOperationType.update,
              data: item.toJson(),
              timestamp: DateTime.now(),
            ),
          );
          _log('Journal queued for Supabase: $id');
        } catch (e) {
          _log('Failed to queue journal to Supabase: $e');
        }
      }
    } catch (e) {
      _log('Failed to update journal: $e');
      rethrow;
    }
  }

  /// Delete a journal
  Future<void> delete(String id) async {
    try {
      final db = await _databaseService.database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      _log('Delete journal: $id');

      if (_supabase.isInitialized) {
        try {
          await _syncManager.queueOperation(
            SyncOperation(
              table: 'journals',
              id: id,
              type: SyncOperationType.delete,
              timestamp: DateTime.now(),
            ),
          );
          _log('Journal delete queued for Supabase: $id');
        } catch (e) {
          _log('Failed to queue delete to Supabase: $e');
        }
      }
    } catch (e) {
      _log('Failed to delete journal: $e');
      rethrow;
    }
  }

  /// Insert multiple journals
  Future<void> insertAll(List<Journal> items) async {
    try {
      final db = await _databaseService.database;
      final batch = db.batch();

      for (final item in items) {
        final encryptedData = await _encryptJournal(item);
        batch.insert(
          _tableName,
          encryptedData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      _log('Batch inserted ${items.length} journals');
    } catch (e) {
      _log('Failed to batch insert journals: $e');
      rethrow;
    }
  }

  /// Query journals by date range
  Future<List<Journal>> getByDateRange(DateTime start, DateTime end) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'date >= ? AND date <= ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'date DESC',
      );

      final journals = await Future.wait(
        maps.map((map) => _decryptAndParseJournal(map)),
      );
      _log('Date range query returned ${journals.length} journals');
      return journals;
    } catch (e) {
      _log('Failed to query journals by date range: $e');
      return [];
    }
  }

  /// Query journals by category ID
  Future<List<Journal>> getByCategoryId(String categoryId) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'categoryId = ?',
        whereArgs: [categoryId],
        orderBy: 'date DESC',
      );

      final journals = await Future.wait(
        maps.map((map) => _decryptAndParseJournal(map)),
      );
      _log('Category query returned ${journals.length} journals');
      return journals;
    } catch (e) {
      _log('Failed to query journals by category: $e');
      return [];
    }
  }

  /// Find journals by title (case-insensitive)
  Future<List<Journal>> findByTitle(String title) async {
    try {
      final journals = await _queryLocal();
      final lowerTitle = title.trim().toLowerCase();
      return journals.where((j) => j.title.trim().toLowerCase() == lowerTitle).toList();
    } catch (e) {
      _log('Failed to find journal by title: $e');
      return [];
    }
  }

  /// Clear all journals
  Future<void> clearAll() async {
    try {
      final db = await _databaseService.database;
      await db.delete(_tableName);
      _log('Cleared all journals');
    } catch (e) {
      _log('Failed to clear journals: $e');
      rethrow;
    }
  }

  /// Query from local SQLite
  Future<List<Journal>> _queryLocal() async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        orderBy: 'date DESC',
      );

      return await Future.wait(
        maps.map((map) => _decryptAndParseJournal(map)),
      );
    } catch (e) {
      _log('Failed to query local journals: $e');
      return [];
    }
  }

  /// Encrypt journal data
  Future<Map<String, dynamic>> _encryptJournal(Journal journal) async {
    final jsonData = journal.toJson();
    final jsonString = journal.toJson().toString();
    final encryptedContent = await EncryptionHelper.encrypt(jsonString);

    return {
      'id': journal.id,
      'categoryId': journal.categoryId,
      'title': await EncryptionHelper.encrypt(journal.title),
      'content': encryptedContent,
      'tags': await EncryptionHelper.encrypt(jsonData['tags'].toString()),
      'date': journal.date.toIso8601String(),
      'createdAt': journal.createdAt.toIso8601String(),
      'updatedAt': journal.updatedAt.toIso8601String(),
      'subject': journal.subject != null
          ? await EncryptionHelper.encrypt(journal.subject!)
          : null,
      'remarks': journal.remarks != null
          ? await EncryptionHelper.encrypt(journal.remarks!)
          : null,
      'mood': journal.mood,
    };
  }

  /// Decrypt and parse journal data
  Future<Journal> _decryptAndParseJournal(Map<String, dynamic> map) async {
    try {
      final decryptedTitle = await EncryptionHelper.decrypt(map['title'] as String);
      final decryptedContent =
          await EncryptionHelper.decrypt(map['content'] as String);

      return Journal(
        id: map['id'] as String,
        categoryId: map['categoryId'] as String,
        title: decryptedTitle,
        content: [],
        tags: [],
        date: DateTime.parse(map['date'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        subject: map['subject'] != null
            ? await EncryptionHelper.decrypt(map['subject'] as String)
            : null,
        remarks: map['remarks'] != null
            ? await EncryptionHelper.decrypt(map['remarks'] as String)
            : null,
        mood: map['mood'] as int?,
      );
    } catch (e) {
      _log('Failed to decrypt journal data: $e');
      return Journal(
        id: map['id'] as String? ?? '',
        categoryId: map['categoryId'] as String? ?? '',
        title: 'Decryption failed',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Log output
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[JournalRepository] $message');
    }
  }
}