import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:flutter/foundation.dart';
import 'services/preference_service.dart';
import 'services/auth_service.dart';
import 'providers/theme_provider.dart';
import 'providers/expense_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    // Initialize FFI for desktop SQFlite
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  await initializeDateFormatting('id_ID', null);
  
  // Initialize Firebase with explicit options for cross-platform support
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBDVTXMvgDk6b8DXaECNMCaPMOu_jnWkSo",
      appId: "1:44979054043:android:81b485c24979edefb873fe",
      messagingSenderId: "44979054043",
      projectId: "coffee-35055",
      storageBucket: "coffee-35055.firebasestorage.app",
    ),
  );

  // Initialize Google Sign-In instance exactly once with the OAuth Client ID
  await GoogleSignIn.instance.initialize(
    clientId: "44979054043-63t9s5r1tbarce01mog9php71ltv6kqd.apps.googleusercontent.com",
  );

  final prefs = await SharedPreferences.getInstance();
  final preferenceService = PreferenceService(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(preferenceService)),
        ChangeNotifierProvider(create: (_) => ExpenseProvider(preferenceService)),
      ],
      child: const ExpenseTrackerApp(),
    ),
  );
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Expense Tracker Pro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: StreamBuilder<User?>(
            stream: AuthService().authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasData) {
                return const HomeScreen();
              } else {
                return const LoginScreen();
              }
            },
          ),
        );
      },
    );
  }
}
