import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/tag.dart';
import '../providers/expense_provider.dart';
import '../services/api_service.dart';
import '../services/sqlite_helper.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;

  const ExpenseFormScreen({Key? key, this.expense}) : super(key: key);

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;
  List<Tag> _selectedTags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense?.title ?? '');
    _amountController = TextEditingController(text: widget.expense?.amount.toString() ?? '');
    _noteController = TextEditingController(text: widget.expense?.note ?? '');
    if (widget.expense != null) {
      _selectedDate = DateTime.parse(widget.expense!.date);
      _selectedTags = List.from(widget.expense!.tags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih kategori terlebih dahulu')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      if (uid == null) {
        throw Exception("Sesi user berakhir. Silakan login kembali.");
      }

      final expense = Expense(
        id: widget.expense?.id,
        title: _titleController.text.trim(),
        amount: int.parse(_amountController.text.trim()),
        date: _selectedDate.toIso8601String(),
        note: _noteController.text.trim(),
        categoryId: _selectedCategory!.id!,
        createdAt: widget.expense?.createdAt ?? DateTime.now().toIso8601String(),
        syncStatus: 'pending',
      );

      if (widget.expense == null) {
        // 1. Simpan lokal ke SQLite (status 'pending')
        final localId = await SQLiteHelper().insertExpense(expense, _selectedTags, uid, syncStatus: 'pending');
        await provider.loadData();
        
        // 2. Hubungi REST API di background untuk sinkronisasi
        try {
          final serverExpense = await ApiService.createExpense(expense.copyWith(tags: _selectedTags));
          // Sinkronisasi sukses: update ID lokal & status menjadi 'synced'
          await SQLiteHelper().updateSyncStatus(localId, uid, 'synced', serverId: serverExpense.id);
          await provider.loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan dan tersinkronisasi ke server.')));
          }
        } catch (e) {
          // Gagal sync (offline): biarkan tetap pending/failed agar disinkronkan nanti
          await SQLiteHelper().updateSyncStatus(localId, uid, 'failed');
          await provider.loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan di penyimpanan lokal (Offline).')));
          }
        }
      } else {
        // 1. Perbarui lokal di SQLite (status 'pending')
        await SQLiteHelper().updateExpense(expense, _selectedTags, uid, syncStatus: 'pending');
        await provider.loadData();

        // 2. Hubungi REST API di background untuk sinkronisasi
        try {
          await ApiService.updateExpense(expense.copyWith(tags: _selectedTags));
          // Perbarui status menjadi 'synced'
          await SQLiteHelper().updateSyncStatus(expense.id!, uid, 'synced');
          await provider.loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembaruan tersinkronisasi ke server.')));
          }
        } catch (e) {
          await SQLiteHelper().updateSyncStatus(expense.id!, uid, 'failed');
          await provider.loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembaruan tersimpan di lokal (Offline).')));
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Tambah Pengeluaran' : 'Edit Pengeluaran'),
        actions: [
          if (widget.expense != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _isLoading ? null : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Pengeluaran?'),
                    content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  setState(() => _isLoading = true);
                  try {
                    final provider = Provider.of<ExpenseProvider>(context, listen: false);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) throw Exception("User session invalid");
                    
                    final idToDelete = widget.expense!.id!;

                    // 1. Hapus dari SQLite lokal
                    await SQLiteHelper().deleteExpense(idToDelete, uid);
                    await provider.loadData();

                    // 2. Coba hapus di server
                    try {
                      await ApiService.deleteExpense(idToDelete);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil dihapus dari server.')));
                      }
                    } catch (e) {
                      // Tetap biarkan terhapus di lokal
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dihapus dari penyimpanan lokal (Offline).')));
                      }
                    }

                    if (!mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                }
              },
            ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          // Initialize selected category if editing
          if (widget.expense != null && _selectedCategory == null) {
            try {
              _selectedCategory = provider.categories.firstWhere((c) => c.id == widget.expense!.categoryId);
            } catch (e) {
              // Ignore if not found
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Pengeluaran',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Judul tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Nominal (${provider.currency})',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Nominal tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Category Dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedCategory?.id,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: provider.categories.isEmpty 
                      ? [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Memuat kategori...'),
                          )
                        ]
                      : provider.categories.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat.id,
                        child: Row(
                          children: [
                            Text(cat.icon),
                            const SizedBox(width: 8),
                            Text(cat.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: provider.categories.isEmpty ? null : (val) {
                      setState(() {
                        if (val != null) {
                          _selectedCategory = provider.categories.firstWhere((c) => c.id == val);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Date Picker
                  ListTile(
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    title: const Text('Tanggal'),
                    subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Multi Tag Selection
                  const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.tags.map((tag) {
                      final isSelected = _selectedTags.any((t) => t.id == tag.id);
                      final color = Color(int.parse(tag.color));
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.removeWhere((t) => t.id == tag.id);
                            }
                          });
                        },
                        selectedColor: color.withOpacity(0.2),
                        checkmarkColor: color,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveExpense,
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
