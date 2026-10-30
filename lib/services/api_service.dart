import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import 'auth_service.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:58348';
    }
    return Platform.isAndroid ? 'http://10.0.2.2:58348' : 'http://127.0.0.1:58348';
  }
  static final AuthService _authService = AuthService();

  // Helper method to generate headers containing the fresh Firebase ID token
  static Future<Map<String, String>> authHeaders() async {
    final token = await _authService.getFreshToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  // Handle common HTTP response errors according to spec (401, 403, 500)
  static void _handleResponseError(http.Response response) {
    if (response.statusCode == 401) {
      // Token invalid/expired -> auto logout
      _authService.logout();
      throw Exception('Session expired');
    } else if (response.statusCode == 403) {
      throw Exception('Akses ditolak: Anda tidak memiliki hak atas data ini');
    } else if (response.statusCode >= 500) {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  // GET /expenses
  static Future<List<Expense>> getExpenses() async {
    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/expenses'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Expense.fromJson(json)).toList();
      } else {
        _handleResponseError(response);
        throw Exception('Failed to load expenses: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // POST /expenses
  static Future<Expense> createExpense(Expense expense) async {
    try {
      final headers = await authHeaders();
      // Ensure we serialize to JSON and ignore any local IDs or user_ids
      final response = await http.post(
        Uri.parse('$baseUrl/expenses'),
        headers: headers,
        body: json.encode(expense.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Expense.fromJson(json.decode(response.body));
      } else {
        _handleResponseError(response);
        throw Exception('Failed to create expense: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // PUT /expenses/<id>
  static Future<Expense> updateExpense(Expense expense) async {
    try {
      final headers = await authHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/expenses/${expense.id}'),
        headers: headers,
        body: json.encode(expense.toJson()),
      );

      if (response.statusCode == 200) {
        return Expense.fromJson(json.decode(response.body));
      } else {
        _handleResponseError(response);
        throw Exception('Failed to update expense: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // DELETE /expenses/<id>
  static Future<void> deleteExpense(int id) async {
    try {
      final headers = await authHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/expenses/$id'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        _handleResponseError(response);
        throw Exception('Failed to delete expense: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
