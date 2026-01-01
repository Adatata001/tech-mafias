// models/daily_log.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyLog {
  final String id;
  final String userId;
  final DateTime date;
  final String note;
  final bool completed;
  final int pointsEarned;
  final DateTime submittedAt;
  final String? screenshotUrl;
  final List<String>? completedTasks;

  DailyLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.note,
    required this.completed,
    required this.pointsEarned,
    required this.submittedAt,
    this.screenshotUrl,
    this.completedTasks,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'note': note,
      'completed': completed,
      'pointsEarned': pointsEarned,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'screenshotUrl': screenshotUrl,
      'completedTasks': completedTasks,
    };
  }

  factory DailyLog.fromJson(Map<String, dynamic> json, String id) {
    // Handle date field - it could be Timestamp or String
    DateTime parseDate(dynamic dateField) {
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is String) {
        return DateTime.parse(dateField);
      } else if (dateField is DateTime) {
        return dateField;
      }
      return DateTime.now();
    }

    // Handle submittedAt field
    DateTime parseSubmittedAt(dynamic submittedAtField) {
      if (submittedAtField is Timestamp) {
        return submittedAtField.toDate();
      } else if (submittedAtField is String) {
        return DateTime.parse(submittedAtField);
      } else if (submittedAtField is DateTime) {
        return submittedAtField;
      }
      return DateTime.now();
    }

    return DailyLog(
      id: id,
      userId: json['userId']?.toString() ?? '',
      date: parseDate(json['date']),
      note: json['note']?.toString() ?? '',
      completed: json['completed'] ?? false,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      submittedAt: parseSubmittedAt(json['submittedAt'] ?? json['createdAt']),
      screenshotUrl: json['screenshotUrl']?.toString(),
      completedTasks: (json['completedTasks'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}