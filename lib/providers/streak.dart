import 'package:flutter/material.dart';
import '../models/daily_log.dart';

class StreakProvider extends ChangeNotifier {
  int _streak = 0;

  int get streak => _streak;

  void calculateStreak(List<DailyLog> logs) {
    if (logs.isEmpty) {
      _streak = 0;
      notifyListeners();
      return;
    }

    logs.sort((a, b) => b.date.compareTo(a.date));

    int currentStreak = 1;

    for (int i = 0; i < logs.length - 1; i++) {
      final diff = logs[i].date
          .difference(logs[i + 1].date)
          .inDays;

      if (diff == 1) {
        currentStreak++;
      } else {
        break;
      }
    }

    _streak = currentStreak;
    notifyListeners();
  }
}
