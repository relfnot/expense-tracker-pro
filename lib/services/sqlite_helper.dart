import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/tag.dart';

class SQLiteHelper {
  static final SQLiteHelper _instance = SQLiteHelper._internal();
  factory SQLiteHelper() => _instance;
  SQLiteHelper._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Create or Insert Expense locally
  Future<int> insertExpense(Expense expense, List<Tag> tags, String userId, {String syncStatus = 'synced'}) async {
    final db = await _dbHelper.database;
    int expenseId = 0;
    
    await db.transaction((txn) async {
      final expenseMap = expense.toMap();
      expenseMap['user_id'] = userId;
      expenseMap['sync_status'] = syncStatus;
      
      expenseId = await txn.insert('expenses_cache', expenseMap);
      
      for (var tag in tags) {
        if (tag.id != null) {
          await txn.insert('expense_tags', {
            'expense_id': expenseId,
            'tag_id': tag.id,
          });
        }
      }
    });
    
    return expenseId;
  }

  // Update Expense locally
  Future<int> updateExpense(Expense expense, List<Tag> tags, String userId, {String syncStatus = 'synced'}) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      final expenseMap = expense.toMap();
      expenseMap['user_id'] = userId;
      expenseMap['sync_status'] = syncStatus;
      
      await txn.update(
        'expenses_cache',
        expenseMap,
        where: 'id = ? AND user_id = ?',
        whereArgs: [expense.id, userId],
      );
      
      await txn.delete(
        'expense_tags',
        where: 'expense_id = ?',
        whereArgs: [expense.id],
      );
      
      for (var tag in tags) {
        if (tag.id != null) {
          await txn.insert('expense_tags', {
            'expense_id': expense.id,
            'tag_id': tag.id,
          });
        }
      }
    });
    
    return expense.id!;
  }

  // Delete Expense locally (or mark as pending delete if we want to sync, but simple delete works)
  Future<int> deleteExpense(int id, String userId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'expenses_cache',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // Get all expenses for a specific user (isolated)
  Future<List<Expense>> getExpenses(String userId) async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> expenseMaps = await db.rawQuery('''
      SELECT e.*, c.name as category_name, c.icon as category_icon, c.color as category_color 
      FROM expenses_cache e 
      LEFT JOIN categories c ON e.category_id = c.id
      WHERE e.user_id = ?
      ORDER BY date DESC, created_at DESC
    ''', [userId]);

    List<Expense> expenses = [];
    for (var map in expenseMaps) {
      Category? category;
      if (map['category_id'] != null) {
        category = Category(
          id: map['category_id'] as int,
          name: map['category_name'] as String,
          icon: map['category_icon'] as String,
          color: map['category_color'] as String,
        );
      }

      final List<Map<String, dynamic>> tagMaps = await db.rawQuery('''
        SELECT t.* FROM tags t
        JOIN expense_tags et ON t.id = et.tag_id
        WHERE et.expense_id = ?
      ''', [map['id']]);

      List<Tag> tags = List.generate(tagMaps.length, (i) => Tag.fromMap(tagMaps[i]));

      // We need to support the sync_status in our models or UI if we want to show it.
      expenses.add(Expense.fromMap(map, category: category, tags: tags));
    }

    return expenses;
  }

  // Get unsynced expenses (pending / failed)
  Future<List<Map<String, dynamic>>> getUnsyncedExpenses(String userId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'expenses_cache',
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'synced'],
    );
  }

  // Update ID and Sync Status after successful sync
  Future<void> updateSyncStatus(int localId, String userId, String syncStatus, {int? serverId}) async {
    final db = await _dbHelper.database;
    if (serverId != null) {
      await db.transaction((txn) async {
        // Update expense ID and sync status
        await txn.update(
          'expenses_cache',
          {
            'id': serverId,
            'sync_status': syncStatus,
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [localId, userId],
        );
        // Update junction table references
        await txn.update(
          'expense_tags',
          {'expense_id': serverId},
          where: 'expense_id = ?',
          whereArgs: [localId],
        );
      });
    } else {
      await db.update(
        'expenses_cache',
        {'sync_status': syncStatus},
        where: 'id = ? AND user_id = ?',
        whereArgs: [localId, userId],
      );
    }
  }

  // Clear cache on logout for security (Data Isolation)
  Future<void> clearCacheOnLogout() async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('expenses_cache');
      await txn.delete('expense_tags');
      await txn.delete('categories');
      await txn.delete('tags');
    });
    // Seed defaults back
    await _dbHelper.seedDefaults();
  }
}
