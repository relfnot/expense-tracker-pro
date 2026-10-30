import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/expense_provider.dart';
import '../widgets/budget_card.dart';
import '../widgets/expense_card.dart';
import '../models/expense.dart';
import '../models/tag.dart';
import 'expense_form_screen.dart';
import 'settings_screen.dart';
import 'category_screen.dart';
import 'tag_screen.dart';
import '../services/api_service.dart';
import '../services/sqlite_helper.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedTagId; // null means "All"
  bool _isOffline = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // 1. Render data dari cache lokal secara instan, diikuti dengan background sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocalAndSync();
    });
  }

  Future<void> _loadLocalAndSync() async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    await provider.loadData();
    _runBackgroundSync();
  }

  Future<void> _runBackgroundSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    final uid = user.uid;
    final sqliteHelper = SQLiteHelper();

    try {
      // Step A: PUSH - Kirim data local yang unsynced (pending/failed) ke Server PHP
      final unsynced = await sqliteHelper.getUnsyncedExpenses(uid);
      for (var item in unsynced) {
        final localId = item['id'] as int;
        final expense = Expense.fromMap(item);
        
        // Fetch tags for this unsynced expense
        final db = await DatabaseHelper().database;
        final List<Map<String, dynamic>> tagMaps = await db.rawQuery('''
          SELECT t.* FROM tags t
          JOIN expense_tags et ON t.id = et.tag_id
          WHERE et.expense_id = ?
        ''', [localId]);
        final tags = List.generate(tagMaps.length, (i) => Tag.fromMap(tagMaps[i]));
        
        final expenseToUpload = expense.copyWith(tags: tags);

        // Upload ke Server
        if (item['sync_status'] == 'pending' || item['sync_status'] == 'failed') {
          final serverExpense = await ApiService.createExpense(expenseToUpload);
          // Update ID local dengan ID dari server dan tandai 'synced'
          await sqliteHelper.updateSyncStatus(localId, uid, 'synced', serverId: serverExpense.id);
        }
      }

      // Step B: PULL - Ambil data terbaru dari Server PHP
      final serverExpenses = await ApiService.getExpenses();

      // Step C: RECONCILIATION - Bersihkan cache lama UID saat ini, batch insert data baru
      final db = await DatabaseHelper().database;
      await db.transaction((txn) async {
        await txn.delete('expenses_cache', where: 'user_id = ?', whereArgs: [uid]);
        
        final batch = txn.batch();
        for (var exp in serverExpenses) {
          final expMap = exp.toMap();
          expMap['user_id'] = uid;
          expMap['sync_status'] = 'synced';
          
          batch.insert('expenses_cache', expMap);
        }
        await batch.commit(noResult: true);
      });

      // Step D: REBUILD - Reload local data ke provider
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      await provider.loadData();

      setState(() {
        _isOffline = false;
      });
    } catch (e) {
      final errMsg = e.toString();
      if (errMsg.contains('Session expired')) {
        // HTTP 401: Auto logout (di-handle oleh ApiService secara internal, tapi kita trigger logout manual jika lolos)
        await AuthService().logout();
      } else if (errMsg.contains('Akses ditolak')) {
        // HTTP 403: Tampilkan SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Akses ditolak: Anda tidak memiliki hak atas data ini"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        // HTTP 500 / SocketException (Offline)
        setState(() {
          _isOffline = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final provider = Provider.of<ExpenseProvider>(context);

    final now = DateTime.now();
    final spentThisMonth = provider.expenses.where((e) {
      try {
        final date = DateTime.parse(e.date);
        return date.year == now.year && date.month == now.month;
      } catch (_) {
        return false;
      }
    }).fold(0, (sum, item) => sum + item.amount);

    final expenses = provider.expenses.where((e) {
      if (_selectedTagId == null) return true;
      return e.tags.any((tag) => tag.id == _selectedTagId);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Expense Tracker Pro'),
        actions: [
          if (_isSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text(
                'Expense Tracker Pro',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(user?.email ?? 'Tidak ada email'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.primary),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Categories'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.label),
              title: const Text('Tags'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TagScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Apakah Anda yakin ingin logout? Data cache lokal akan dihapus.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await AuthService().logout();
                }
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _runBackgroundSync,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Banner Offline
            if (_isOffline)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.amber),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Sedang offline, menampilkan data tersimpan',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _runBackgroundSync,
                      ),
                    ],
                  ),
                ),
              ),

            // Budget Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: BudgetCard(
                  totalBudget: provider.monthlyBudget,
                  spent: spentThisMonth,
                  currency: provider.currency,
                ),
              ),
            ),
            
            // Filter Chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Semua'),
                        selected: _selectedTagId == null,
                        onSelected: (val) {
                          setState(() {
                            _selectedTagId = null;
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    ...provider.tags.map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag.name),
                          selected: _selectedTagId == tag.id,
                          onSelected: (val) {
                            setState(() {
                              _selectedTagId = val ? tag.id : null;
                            });
                          },
                          selectedColor: Color(int.parse(tag.color)).withOpacity(0.2),
                          checkmarkColor: Color(int.parse(tag.color)),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            // Expense List
            expenses.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 80,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada pengeluaran',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final expense = expenses[index];
                        return ExpenseCard(
                          expense: expense,
                          currency: provider.currency,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExpenseFormScreen(expense: expense),
                              ),
                            ).then((_) => _runBackgroundSync());
                          },
                        );
                      },
                      childCount: expenses.length,
                    ),
                  ),
            
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseFormScreen())).then((_) => _runBackgroundSync());
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Pengeluaran'),
      ),
    );
  }
}
