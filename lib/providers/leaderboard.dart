import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


enum LeaderboardFilter { day, week, month, all }

class LeaderboardProvider with ChangeNotifier {
  LeaderboardFilter _filter = LeaderboardFilter.all;
  bool _isLoading = false;
  String? _error;

  LeaderboardFilter get filter => _filter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setFilter(LeaderboardFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  // Get leaderboard stream with proper date filtering
  Stream<List<Map<String, dynamic>>> leaderboardStream() {
    try {
      final now = DateTime.now();
      Query query = FirebaseFirestore.instance
          .collection('leaderboard');

      // Apply date filter
      switch (_filter) {
        case LeaderboardFilter.day:
          final today = DateTime(now.year, now.month, now.day);
          query = query.where('date', isEqualTo: Timestamp.fromDate(today));
          break;
        case LeaderboardFilter.week:
          final weekAgo = now.subtract(const Duration(days: 7));
          query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo));
          break;
        case LeaderboardFilter.month:
          final monthAgo = now.subtract(const Duration(days: 30));
          query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo));
          break;
        case LeaderboardFilter.all:
          // No date filter for "all"
          break;
      }

      return query
          .orderBy('totalPoints', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'userId': data['userId'] ?? '',
                'username': data['username'] ?? 'Unknown',
                'totalPoints': (data['totalPoints'] as num?)?.toInt() ?? 0,
                'dailyPoints': (data['dailyPoints'] as num?)?.toInt() ?? 0,
                'date': (data['date'] as Timestamp?)?.toDate() ?? now,
                'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? now,
              };
            }).toList();
          })
          .handleError((error) {
            print('Error in leaderboard stream: $error');
            return <Map<String, dynamic>>[];
          });
    } catch (e) {
      print('Error creating leaderboard stream: $e');
      return Stream.value([]);
    }
  }

  // Alternative: Get all users sorted by points
  Stream<List<Map<String, dynamic>>> usersLeaderboardStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('points', isGreaterThan: 0)
        .orderBy('points', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'userId': doc.id,
              'username': data['username'] ?? 'Unknown',
              'email': data['email'] ?? '',
              'points': (data['points'] as num?)?.toInt() ?? 0,
              'streak': (data['streak'] as num?)?.toInt() ?? 0,
              'role': data['role'] ?? 'Member',
              'profilePhoto': data['profilePhoto'],
            };
          }).toList();
        })
        .handleError((error) {
          print('Error in users leaderboard stream: $error');
          return <Map<String, dynamic>>[];
        });
  }

  // Get combined leaderboard (users collection)
  Stream<List<Map<String, dynamic>>> getCombinedLeaderboard() {
    return usersLeaderboardStream();
  }

  // Load initial leaderboard data
  Future<void> fetchLeaderboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('points', descending: true)
          .get();

      print('Loaded ${snapshot.docs.length} users for leaderboard');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('Error fetching leaderboard: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}