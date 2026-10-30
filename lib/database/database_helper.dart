import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import '../models/tag.dart';
import '../models/expense.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expense_tracker_pro.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Categories Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE,
          icon TEXT,
          color TEXT
        )
      ''');

      // Tags Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tags(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE,
          color TEXT
        )
      ''');

      // Seed categories if empty
      final List<Map<String, dynamic>> catCount = await db.rawQuery('SELECT COUNT(*) as count FROM categories');
      if (catCount.isEmpty || catCount.first['count'] == 0) {
        await _insertDefaultCategories(db);
      }

      // Seed tags if empty
      final List<Map<String, dynamic>> tagCount = await db.rawQuery('SELECT COUNT(*) as count FROM tags');
      if (tagCount.isEmpty || tagCount.first['count'] == 0) {
        await _insertDefaultTags(db);
      }
    }

    if (oldVersion < 3) {
      // Drop old expenses table
      await db.execute('DROP TABLE IF EXISTS expenses');
      await db.execute('DROP TABLE IF EXISTS expenses_cache');
      
      // Create new expenses_cache table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses_cache(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          title TEXT,
          amount INTEGER,
          date TEXT,
          note TEXT,
          category_id INTEGER,
          created_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
        )
      ''');

      // Drop and recreate expense_tags referencing expenses_cache
      await db.execute('DROP TABLE IF EXISTS expense_tags');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_tags(
          expense_id INTEGER,
          tag_id INTEGER,
          PRIMARY KEY (expense_id, tag_id),
          FOREIGN KEY (expense_id) REFERENCES expenses_cache (id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Categories Table
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        icon TEXT,
        color TEXT
      )
    ''');

    // Tags Table
    await db.execute('''
      CREATE TABLE tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        color TEXT
      )
    ''');

    // Expenses Cache Table
    await db.execute('''
      CREATE TABLE expenses_cache(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        title TEXT,
        amount INTEGER,
        date TEXT,
        note TEXT,
        category_id INTEGER,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Expense_Tags Junction Table
    await db.execute('''
      CREATE TABLE expense_tags(
        expense_id INTEGER,
        tag_id INTEGER,
        PRIMARY KEY (expense_id, tag_id),
        FOREIGN KEY (expense_id) REFERENCES expenses_cache (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    // Insert Default Categories
    await _insertDefaultCategories(db);
    // Insert Default Tags
    await _insertDefaultTags(db);
  }

  Future<void> _insertDefaultCategories(Database db) async {
    List<Map<String, dynamic>> defaults = [
      {'name': 'Makanan', 'icon': '🍔', 'color': '0xFFFF9800'},
      {'name': 'Transportasi', 'icon': '🚗', 'color': '0xFF2196F3'},
      {'name': 'Belanja', 'icon': '🛒', 'color': '0xFFE91E63'},
      {'name': 'Tagihan', 'icon': '💡', 'color': '0xFFF44336'},
      {'name': 'Hiburan', 'icon': '🎮', 'color': '0xFF9C27B0'},
    ];
    for (var cat in defaults) {
      await db.insert('categories', cat, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertDefaultTags(Database db) async {
    List<Map<String, dynamic>> defaults = [
      {'name': 'Urgent', 'color': '0xFFF44336'},
      {'name': 'Weekend', 'color': '0xFF4CAF50'},
      {'name': 'Kerja', 'color': '0xFF2196F3'},
      {'name': 'Liburan', 'color': '0xFFFFEB3B'},
      {'name': 'Kebutuhan Pokok', 'color': '0xFFFF9800'},
    ];
    for (var tag in defaults) {
      await db.insert('tags', tag, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // Seeding method to restore default categories and tags on cache clear
  Future<void> seedDefaults() async {
    Database db = await database;
    await _insertDefaultCategories(db);
    await _insertDefaultTags(db);
  }

  // CRUD Category
  Future<int> insertCategory(Category category) async {
    Database db = await database;
    return await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Category>> getCategories() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> updateCategory(Category category) async {
    Database db = await database;
    return await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(int id) async {
    Database db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Tag
  Future<int> insertTag(Tag tag) async {
    Database db = await database;
    return await db.insert('tags', tag.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Tag>> getTags() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tags');
    return List.generate(maps.length, (i) => Tag.fromMap(maps[i]));
  }

  Future<int> updateTag(Tag tag) async {
    Database db = await database;
    return await db.update('tags', tag.toMap(), where: 'id = ?', whereArgs: [tag.id]);
  }

  Future<int> deleteTag(int id) async {
    Database db = await database;
    return await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }
}
