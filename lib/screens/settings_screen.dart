import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _budgetController;

  @override
  void initState() {
    super.initState();
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    _budgetController = TextEditingController(text: expenseProvider.monthlyBudget.toString());
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer2<ThemeProvider, ExpenseProvider>(
        builder: (context, themeProvider, expenseProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Dark Mode Toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: themeProvider.isDarkMode,
                  onChanged: (val) {
                    themeProvider.toggleTheme(val);
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Currency Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<String>(
                    value: expenseProvider.currency,
                    decoration: const InputDecoration(
                      labelText: 'Mata Uang (Currency)',
                      border: InputBorder.none,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'IDR', child: Text('IDR (Rupiah)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (Dolar)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (Euro)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        expenseProvider.updateCurrency(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Monthly Budget
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _budgetController,
                    decoration: const InputDecoration(
                      labelText: 'Target Budget Bulanan',
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (val) {
                      final budget = int.tryParse(val);
                      if (budget != null) {
                        expenseProvider.updateBudget(budget);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget berhasil disimpan')));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Tekan "Enter" / "Done" pada keyboard untuk menyimpan budget.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(height: 24),

              // Logout Card Option
              Card(
                color: Colors.red.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.redAccent, width: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Log Out', 
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Keluar dan bersihkan cache local database'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Log Out'),
                        content: const Text('Apakah Anda yakin ingin keluar? Data cache lokal akan dihapus demi keamanan data Anda.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true), 
                            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await AuthService().logout();
                      if (mounted) {
                        Navigator.pop(context); // Close SettingsScreen
                      }
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
