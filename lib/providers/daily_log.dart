import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/daily_log.dart';

class DailyLogProvider with ChangeNotifier {
  final List<DailyLog> _logs = [];
  bool _isLoading = false;
  String? _error;

  List<DailyLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchDailyLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logs.clear();
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch logs without ordering first
      final snapshot = await FirebaseFirestore.instance
          .collection('daily_logs')
          .where('userId', isEqualTo: user.uid)
          .get();

      _logs.clear();

      if (snapshot.docs.isNotEmpty) {
        // Convert to list and sort manually
        final unsortedLogs = snapshot.docs.map((doc) {
          return DailyLog.fromJson(doc.data(), doc.id);
        }).toList();
        
        // Sort by date descending manually
        unsortedLogs.sort((a, b) => b.date.compareTo(a.date));
        
        _logs.addAll(unsortedLogs);
        print('Loaded ${_logs.length} daily logs');
      }
    } catch (e) {
      print('Error fetching daily logs: $e');
      _error = e.toString();
      _logs.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitDailyLog({
    required String note,
    required String screenshotUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check if already submitted today
      final hasSubmittedToday = _logs.any((log) =>
          log.date.year == today.year &&
          log.date.month == today.month &&
          log.date.day == today.day);

      if (hasSubmittedToday) {
        throw Exception('You have already submitted your daily log today');
      }

      // Calculate streak
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final hasSubmittedYesterday = _logs.any((log) =>
          log.date.year == yesterday.year &&
          log.date.month == yesterday.month &&
          log.date.day == yesterday.day);

      int newStreak = 1; // Start with 1 for today
      
      if (hasSubmittedYesterday) {
        // Get user's current streak from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        final currentStreak = (userDoc.data()?['streak'] as int?) ?? 0;
        newStreak = currentStreak + 1;
      } else {
        // If didn't submit yesterday, check if streak should be reset
        if (_logs.isNotEmpty) {
          _logs.sort((a, b) => b.date.compareTo(a.date));
          final lastLog = _logs.first;
          final lastLogDate = lastLog.date;
          
          // Check if last submission was more than 1 day ago
          final daysSinceLast = today.difference(
            DateTime(lastLogDate.year, lastLogDate.month, lastLogDate.day)
          ).inDays;
          
          if (daysSinceLast > 1) {
            // More than 1 day gap, reset streak to 1
            newStreak = 1;
          }
        }
      }

      // Prepare daily log data - ALWAYS 20 POINTS
      const pointsEarned = 20; // Fixed 20 points per submission
      final logData = {
        'userId': user.uid,
        'note': note,
        'screenshotUrl': screenshotUrl,
        'pointsEarned': pointsEarned,
        'date': Timestamp.fromDate(today),
        'createdAt': FieldValue.serverTimestamp(),
        'completed': true,
      };

      // Add to daily logs collection
      await FirebaseFirestore.instance
          .collection('daily_logs')
          .add(logData);

      // Update user's points and streak in users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'points': FieldValue.increment(pointsEarned), // Add 20 points
        'streak': newStreak,
        'lastSubmission': FieldValue.serverTimestamp(),
      });

      // Try to update leaderboard (but don't fail if it errors)
      try {
        await _updateLeaderboard(user.uid, pointsEarned);
      } catch (e) {
        print('Leaderboard update failed (non-critical): $e');
        // Don't rethrow - leaderboard failure shouldn't fail the whole submission
      }

      // Refresh local data
      await fetchDailyLogs();
      
      _isLoading = false;
      notifyListeners();

    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _updateLeaderboard(String userId, int pointsEarned) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // First get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        print('User document not found for leaderboard update');
        return;
      }
      
      final userData = userDoc.data();
      final username = userData?['username']?.toString() ?? 'Unknown';
      final currentPoints = (userData?['points'] as num?)?.toInt() ?? 0;
      
      // Check if leaderboard entry exists for today
      final leaderboardQuery = await FirebaseFirestore.instance
          .collection('leaderboard')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .limit(1)
          .get();

      if (leaderboardQuery.docs.isNotEmpty) {
        // Update existing entry
        await leaderboardQuery.docs.first.reference.update({
          'totalPoints': currentPoints + pointsEarned,
          'dailyPoints': FieldValue.increment(pointsEarned),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Updated existing leaderboard entry');
      } else {
        // Create new entry
        await FirebaseFirestore.instance
            .collection('leaderboard')
            .add({
              'userId': userId,
              'username': username,
              'totalPoints': currentPoints + pointsEarned,
              'dailyPoints': pointsEarned,
              'date': Timestamp.fromDate(today),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        print('Created new leaderboard entry');
      }
    } catch (e) {
      print('Error updating leaderboard: $e');
      // Don't throw - let the main submission succeed even if leaderboard fails
    }
  }

  // Check if user has submitted today
  bool hasSubmittedToday() {
    final today = DateTime.now();
    return _logs.any((log) =>
        log.date.year == today.year &&
        log.date.month == today.month &&
        log.date.day == today.day);
  }

  // Get today's points (should be 20 if submitted today)
  int getTodayPoints() {
    final today = DateTime.now();
    for (var log in _logs) {
      if (log.date.year == today.year &&
          log.date.month == today.month &&
          log.date.day == today.day) {
        return log.pointsEarned;
      }
    }
    return 0;
  }

  // Get total points from all logs
  int getTotalPoints() {
    return _logs.fold(0, (sum, log) => sum + log.pointsEarned);
  }

  // Get current streak (by checking consecutive days with submissions)
  Future<int> getCurrentStreak(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      return (userDoc.data()?['streak'] as int?) ?? 0;
    } catch (e) {
      print('Error getting streak: $e');
      return 0;
    }
  }

  // Get recent activity (last 7 days)
  List<DailyLog> getRecentActivity({int days = 7}) {
    final now = DateTime.now();
    final recentLogs = <DailyLog>[];
    
    for (var log in _logs) {
      final daysDiff = now.difference(log.date).inDays;
      if (daysDiff <= days) {
        recentLogs.add(log);
      }
    }
    
    return recentLogs;
  }

  // Get submission history for a specific month
  List<DailyLog> getMonthlyActivity(int year, int month) {
    return _logs.where((log) =>
        log.date.year == year && log.date.month == month).toList();
  }

  // Check if user submitted on a specific date
  bool didSubmitOnDate(DateTime date) {
    return _logs.any((log) =>
        log.date.year == date.year &&
        log.date.month == date.month &&
        log.date.day == date.day);
  }

  // Get the last submission date
  DateTime? getLastSubmissionDate() {
    if (_logs.isEmpty) return null;
    
    _logs.sort((a, b) => b.date.compareTo(a.date));
    return _logs.first.date;
  }

  // Calculate longest streak
  int calculateLongestStreak() {
    if (_logs.isEmpty) return 0;
    
    // Sort logs by date ascending
    final sortedLogs = List<DailyLog>.from(_logs)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    int longestStreak = 0;
    int currentStreak = 1;
    
    for (int i = 1; i < sortedLogs.length; i++) {
      final prevDate = sortedLogs[i - 1].date;
      final currentDate = sortedLogs[i].date;
      
      final daysDiff = currentDate.difference(prevDate).inDays;
      
      if (daysDiff == 1) {
        // Consecutive day
        currentStreak++;
      } else {
        // Break in streak
        longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
        currentStreak = 1;
      }
    }
    
    // Check last streak
    longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
    
    return longestStreak;
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Add a test log (for development)
  Future<void> addTestLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final logData = {
      'userId': user.uid,
      'note': 'Test daily log submission',
      'screenshotUrl': 'https://drive.google.com/drive/folders/test123',
      'pointsEarned': 20,
      'date': Timestamp.fromDate(now),
      'createdAt': FieldValue.serverTimestamp(),
      'completed': true,
    };

    try {
      await FirebaseFirestore.instance
          .collection('daily_logs')
          .add(logData);
      
      await fetchDailyLogs();
    } catch (e) {
      print('Error adding test log: $e');
    }
  }

  // Refresh user data after submission (call this from HomeTab)
  Future<void> refreshUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Re-fetch logs to get updated data
      await fetchDailyLogs();
      notifyListeners();
    }
  }
}