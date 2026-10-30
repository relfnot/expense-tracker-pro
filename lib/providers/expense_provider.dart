import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database_helper.dart';
import '../services/sqlite_helper.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/tag.dart';
import '../services/preference_service.dart';

class ExpenseProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final PreferenceService _preferenceService;

  List<Expense> _expenses = [];
  List<Category> _categories = [];
  List<Tag> _tags = [];

  List<Expense> get expenses => _expenses;
  List<Category> get categories => _categories;
  List<Tag> get tags => _tags;

  int get monthlyBudget => _preferenceService.monthlyBudget;
  String get currency => _preferenceService.currency;

  ExpenseProvider(this._preferenceService) {
    loadData();
  }

  Future<void> loadData() async {
    await Future.wait([
      _loadExpenses(),
      _loadCategories(),
      _loadTags(),
    ]);
  }

  Future<void> _loadExpenses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _expenses = await _sqliteHelper.getExpenses(uid);
    } else {
      _expenses = [];
    }
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    _categories = await _dbHelper.getCategories();
    notifyListeners();
  }

  Future<void> _loadTags() async {
    _tags = await _dbHelper.getTags();
    notifyListeners();
  }

  // --- Expenses ---
  Future<void> addExpense(Expense expense, List<Tag> selectedTags) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _sqliteHelper.insertExpense(expense, selectedTags, uid, syncStatus: 'pending');
      await _loadExpenses();
    }
  }

  Future<void> updateExpense(Expense expense, List<Tag> selectedTags) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _sqliteHelper.updateExpense(expense, selectedTags, uid, syncStatus: 'pending');
      await _loadExpenses();
    }
  }

  Future<void> deleteExpense(int id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _sqliteHelper.deleteExpense(id, uid);
      await _loadExpenses();
    }
  }

  // --- Categories ---
  Future<void> addCategory(Category category) async {
    await _dbHelper.insertCategory(category);
    await _loadCategories();
    await _loadExpenses();
  }

  Future<void> updateCategory(Category category) async {
    await _dbHelper.updateCategory(category);
    await _loadCategories();
    await _loadExpenses();
  }

  Future<void> deleteCategory(int id) async {
    await _dbHelper.deleteCategory(id);
    await _loadCategories();
    await _loadExpenses();
  }

  // --- Tags ---
  Future<void> addTag(Tag tag) async {
    await _dbHelper.insertTag(tag);
    await _loadTags();
    await _loadExpenses();
  }

  Future<void> updateTag(Tag tag) async {
    await _dbHelper.updateTag(tag);
    await _loadTags();
    await _loadExpenses();
  }

  Future<void> deleteTag(int id) async {
    await _dbHelper.deleteTag(id);
    await _loadTags();
    await _loadExpenses();
  }

  // --- Budget/Currency ---
  Future<void> updateBudget(int budget) async {
    await _preferenceService.setMonthlyBudget(budget);
    notifyListeners();
  }

  Future<void> updateCurrency(String newCurrency) async {
    await _preferenceService.setCurrency(newCurrency);
    notifyListeners();
  }

  // Derived getters for Stats
  int get totalExpensesThisMonth {
    final now = DateTime.now();
    return _expenses.where((e) {
      try {
        final date = DateTime.parse(e.date);
        return date.year == now.year && date.month == now.month;
      } catch (_) {
        return false;
      }
    }).fold(0, (sum, item) => sum + item.amount);
  }

  double get budgetProgress {
    if (monthlyBudget == 0) return 0.0;
    return (totalExpensesThisMonth / monthlyBudget).clamp(0.0, 1.0);
  }
}
