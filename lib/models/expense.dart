import 'category.dart';
import 'tag.dart';

class Expense {
  final int? id;
  final String title;
  final int amount;
  final String date;
  final String note;
  final int categoryId;
  final String createdAt;
  final String syncStatus;
  
  // Optional relational fields for UI
  final Category? category;
  final List<Tag> tags;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.note,
    required this.categoryId,
    required this.createdAt,
    this.syncStatus = 'synced',
    this.category,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date,
      'note': note,
      'category_id': categoryId,
      'created_at': createdAt,
      'sync_status': syncStatus,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map, {Category? category, List<Tag>? tags}) {
    return Expense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: map['date'],
      note: map['note'],
      categoryId: map['category_id'],
      createdAt: map['created_at'],
      syncStatus: map['sync_status'] ?? 'synced',
      category: category,
      tags: tags ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date,
      'note': note,
      'category_id': categoryId,
      'created_at': createdAt,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json, {Category? category, List<Tag>? tags}) {
    return Expense(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      date: json['date'],
      note: json['note'],
      categoryId: json['category_id'],
      createdAt: json['created_at'],
      syncStatus: 'synced', // API data is always synced
      category: category,
      tags: tags ?? [],
    );
  }

  Expense copyWith({
    int? id,
    String? title,
    int? amount,
    String? date,
    String? note,
    int? categoryId,
    String? createdAt,
    String? syncStatus,
    Category? category,
    List<Tag>? tags,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }
}
