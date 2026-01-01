import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import local phase files (optional - fallback)
import '../phases/backend.dart';
import '../phases/frontend.dart';
import '../phases/product_design.dart';
import '../phases/graphics_design.dart';
import '../phases/social_media_management.dart';
import '../phases/project_management.dart';
import '../phases/creative_director.dart';

class RoadmapTask {
  final String id;
  final String title;
  final String description;
  final int week;
  final int day;
  bool completed;
  String? submittedFileUrl;
  int votes;
  int points;
  List<String> resources;
  String createdBy;
  String role;

  RoadmapTask({
    required this.id,
    required this.title,
    required this.description,
    required this.week,
    required this.day,
    this.completed = false,
    this.submittedFileUrl,
    this.votes = 0,
    this.points = 10,
    this.resources = const [],
    required this.createdBy,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'week': week,
      'day': day,
      'completed': completed,
      'submittedFileUrl': submittedFileUrl,
      'votes': votes,
      'points': points,
      'resources': resources,
      'createdBy': createdBy,
      'role': role,
    };
  }

  factory RoadmapTask.fromJson(Map<String, dynamic> json) {
    return RoadmapTask(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Task',
      description: json['description']?.toString() ?? '',
      week: (json['week'] as num?)?.toInt() ?? 1,
      day: (json['day'] as num?)?.toInt() ?? 1,
      completed: json['completed'] ?? false,
      submittedFileUrl: json['submittedFileUrl']?.toString(),
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 10,
      resources: List<String>.from(json['resources'] as List<dynamic>? ?? []),
      createdBy: json['createdBy']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
    );
  }
}

class RoadmapWeek {
  final int weekNumber;
  final List<RoadmapTask> tasks;

  RoadmapWeek({
    required this.weekNumber,
    required this.tasks,
  });

  Map<String, dynamic> toJson() {
    return {
      'weekNumber': weekNumber,
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
  }

  factory RoadmapWeek.fromJson(Map<String, dynamic> json) {
    final tasksData = json['tasks'] as List<dynamic>? ?? [];
    final tasks = tasksData.map((t) {
      final taskJson = t as Map<String, dynamic>? ?? {};
      return RoadmapTask.fromJson(taskJson);
    }).toList();

    return RoadmapWeek(
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
      tasks: tasks,
    );
  }
}

class Roadmap {
  final String id;
  final String role;
  final String title;
  final String description;
  final List<RoadmapWeek> weeks;
  final bool isActive;
  final int totalTasks;
  final int totalWeeks;
  final String createdBy;
  final String createdByEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  Roadmap({
    required this.id,
    required this.role,
    required this.title,
    required this.description,
    required this.weeks,
    required this.isActive,
    required this.totalTasks,
    required this.totalWeeks,
    required this.createdBy,
    required this.createdByEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Roadmap.fromJson(Map<String, dynamic> json, String id) {
    final weeksData = json['weeks'] as List<dynamic>? ?? [];
    
    // Group tasks by week
    final Map<int, List<RoadmapTask>> tasksByWeek = {};
    
    // First, collect all tasks from the weeks array
    for (var i = 0; i < weeksData.length; i++) {
      final weekData = weeksData[i] as Map<String, dynamic>? ?? {};
      final tasksData = weekData['tasks'] as List<dynamic>? ?? [];
      
      for (var taskData in tasksData) {
        final taskJson = taskData as Map<String, dynamic>? ?? {};
        final task = RoadmapTask.fromJson(taskJson);
        
        if (!tasksByWeek.containsKey(task.week)) {
          tasksByWeek[task.week] = [];
        }
        tasksByWeek[task.week]!.add(task);
      }
    }
    
    // Create RoadmapWeek objects for each week
    final weeks = tasksByWeek.entries.map((entry) {
      return RoadmapWeek(
        weekNumber: entry.key,
        tasks: entry.value,
      );
    }).toList()
    ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    return Roadmap(
      id: id,
      role: json['role']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      weeks: weeks,
      isActive: json['isActive'] ?? true,
      totalTasks: (json['totalTasks'] as num?)?.toInt() ?? 0,
      totalWeeks: (json['totalWeeks'] as num?)?.toInt() ?? 0,
      createdBy: json['createdBy']?.toString() ?? '',
      createdByEmail: json['createdByEmail']?.toString() ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'title': title,
      'description': description,
      'weeks': _weeksToFirestoreFormat(),
      'isActive': isActive,
      'totalTasks': totalTasks,
      'totalWeeks': totalWeeks,
      'createdBy': createdBy,
      'createdByEmail': createdByEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Convert weeks back to Firestore format
  List<Map<String, dynamic>> _weeksToFirestoreFormat() {
    // Firestore expects an array where each element has a 'tasks' array
    // We need to reconstruct this from our grouped weeks
    final List<Map<String, dynamic>> firestoreWeeks = [];
    
    for (int weekNum = 1; weekNum <= totalWeeks; weekNum++) {
      final week = weeks.firstWhere(
        (w) => w.weekNumber == weekNum,
        orElse: () => RoadmapWeek(weekNumber: weekNum, tasks: []),
      );
      
      firestoreWeeks.add({
        'weekNumber': weekNum,
        'tasks': week.tasks.map((t) => t.toJson()).toList(),
      });
    }
    
    return firestoreWeeks;
  }
}

class RoadmapProvider with ChangeNotifier {
  Roadmap? _roadmap;
  bool _isLoading = false;
  String? _error;
  String? _currentRole;

  Roadmap? get roadmap => _roadmap;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentRole => _currentRole;

  List<RoadmapWeek> get weeks => _roadmap?.weeks ?? [];

  // Load roadmap based on role
  Future<void> loadRoadmap(String role) async {
    _currentRole = role;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Your Firestore uses role as document ID (e.g., "backend-dev")
      // We need to match this format
      final roleId = role.toLowerCase().replaceAll(' ', '-');
      
      print('Loading roadmap for role: $role, document ID: $roleId');

      final snapshot = await FirebaseFirestore.instance
          .collection('roadmaps')
          .doc(roleId)
          .get();

      if (!snapshot.exists) {
        print('Roadmap not found in Firestore for role: $roleId');
        _error = 'No roadmap found for $role. Please contact admin.';
        _roadmap = null;
        
        // Fallback to local data if available
        await _loadLocalRoadmap(role);
      } else {
        final data = snapshot.data();
        if (data == null) {
          _error = 'Roadmap data is empty for $role';
          _roadmap = null;
          await _loadLocalRoadmap(role);
        } else {
          print('Roadmap data loaded from Firestore for $roleId');
          print('Data structure keys: ${data.keys}');
          print('Has weeks array: ${data['weeks'] != null}');
          
          if (data['weeks'] != null) {
            print('Weeks array length: ${(data['weeks'] as List).length}');
          }
          
          _roadmap = Roadmap.fromJson(data, snapshot.id);
          _error = null;
          
          print('Roadmap loaded: ${_roadmap!.title}');
          print('Total weeks: ${_roadmap!.weeks.length}');
          print('Total tasks: ${_roadmap!.totalTasks}');
        }
      }
    } catch (e) {
      print('Error fetching roadmap from Firestore: $e');
      _error = 'Error loading roadmap: ${e.toString()}';
      _roadmap = null;
      
      // Try loading local roadmap as fallback
      await _loadLocalRoadmap(role);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fallback to load local roadmap data
  Future<void> _loadLocalRoadmap(String role) async {
    try {
      print('Loading local roadmap for role: $role');
      
      // Convert local data to match your Firestore structure
      List<Map<String, dynamic>> localWeeks = [];
      
      // Helper to convert local roadmap data
      List<Map<String, dynamic>> convertLocalRoadmap(List<dynamic> localData, String roleSlug) {
        final Map<int, List<Map<String, dynamic>>> tasksByWeek = {};
        
        for (var item in localData) {
          final day = item.day;
          final week = ((day - 1) ~/ 7) + 1;
          
          if (!tasksByWeek.containsKey(week)) {
            tasksByWeek[week] = [];
          }
          
          tasksByWeek[week]!.add({
            'id': '$roleSlug-w$week-d$day',
            'title': item.title,
            'description': item.description,
            'week': week,
            'day': day,
            'completed': false,
            'votes': 0,
            'points': 10,
            'resources': [],
            'createdBy': 'system',
            'role': roleSlug,
          });
        }
        
        return tasksByWeek.entries.map((entry) {
          return {
            'weekNumber': entry.key,
            'tasks': entry.value,
          };
        }).toList();
      }
      
      switch (role.toLowerCase()) {
        case 'backend developer':
          localWeeks = convertLocalRoadmap(backendRoadmap, 'backend-dev');
          break;
          
        case 'frontend developer':
          localWeeks = convertLocalRoadmap(frontendRoadmap, 'frontend-dev');
          break;
          
        case 'product designer':
          localWeeks = convertLocalRoadmap(productDesignRoadmap, 'product-designer');
          break;
          
        case 'graphics designer':
          localWeeks = convertLocalRoadmap(graphicsDesignRoadmap, 'graphic-designer');
          break;
          
        case 'social media manager':
          localWeeks = convertLocalRoadmap(socialMediaManagementRoadmap, 'social-media-manager');
          break;
          
        case 'project manager':
          localWeeks = convertLocalRoadmap(projectManagementRoadmap, 'project-manager');
          break;
          
        case 'creative director':
          localWeeks = convertLocalRoadmap(creativeDirectorRoadmap, 'creative-director');
          break;
          
        default:
          localWeeks = [];
      }

      if (localWeeks.isNotEmpty) {
        // Calculate total tasks
        int totalTasks = 0;
        for (var week in localWeeks) {
          totalTasks += (week['tasks'] as List).length;
        }
        
        final weeks = localWeeks.map((w) => RoadmapWeek.fromJson(w)).toList();
        
        _roadmap = Roadmap(
          id: role.toLowerCase().replaceAll(' ', '-'),
          role: role,
          title: '$role Roadmap',
          description: 'Complete guide to becoming a $role',
          weeks: weeks,
          isActive: true,
          totalTasks: totalTasks,
          totalWeeks: weeks.length,
          createdBy: 'system',
          createdByEmail: 'system@techmafias.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        if (_error == 'No roadmap found for $role. Please contact admin.') {
          _error = 'Using local roadmap data for $role';
        }
        print('Local roadmap loaded with ${weeks.length} weeks and $totalTasks tasks');
      } else if (_error == null) {
        _error = 'No roadmap data available for $role';
      }
    } catch (e) {
      print('Error loading local roadmap: $e');
      if (_error == null) {
        _error = 'Failed to load roadmap data: ${e.toString()}';
      }
    }
  }

  // ========== NEW METHOD: Submit task with Google Drive link ==========
  Future<void> submitTaskLink({
    required String taskId,
    required String driveLink,
  }) async {
    if (_roadmap == null || _currentRole == null) {
      throw Exception('Roadmap not loaded or no current role');
    }

    try {
      _isLoading = true;
      notifyListeners();
      
      // Find the task
      RoadmapTask? targetTask;
      
      for (var week in _roadmap!.weeks) {
        for (var task in week.tasks) {
          if (task.id == taskId) {
            targetTask = task;
            break;
          }
        }
        if (targetTask != null) break;
      }

      if (targetTask == null) {
        throw Exception('Task not found');
      }

      // Update task
      targetTask.submittedFileUrl = driveLink;
      targetTask.completed = true;

      // Update Firestore
      final roleId = _currentRole!.toLowerCase().replaceAll(' ', '-');
      
      // Create submission record
      final user = FirebaseAuth.instance.currentUser;
      final submissionData = {
        'taskId': taskId,
        'userId': user?.uid,
        'userEmail': user?.email,
        'userRole': _currentRole,
        'driveLink': driveLink,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'submitted',
        'pointsAwarded': targetTask.points,
        'week': targetTask.week,
        'day': targetTask.day,
        'taskTitle': targetTask.title,
        'taskDescription': targetTask.description,
      };

      // Add to submissions collection
      await FirebaseFirestore.instance
          .collection('submissions')
          .add(submissionData);

      // Update roadmap document
      await FirebaseFirestore.instance
          .collection('roadmaps')
          .doc(roleId)
          .update(_roadmap!.toJson());

      _isLoading = false;
      notifyListeners();
      
      print('Task link submitted successfully: $taskId');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error submitting task link: $e');
      rethrow;
    }
  }


  // Helper method to get content type
  // ignore: unused_element
  String _getContentType(String fileExtension) {
    switch (fileExtension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  // ========== EXISTING METHODS ==========

  // Mark task as completed
  Future<void> completeTask(String taskId) async {
    if (_roadmap == null) return;

    try {
      bool taskFound = false;
      
      for (var week in _roadmap!.weeks) {
        for (var task in week.tasks) {
          if (task.id == taskId && !task.completed) {
            task.completed = true;
            taskFound = true;
            
            // Update Firestore if we have the role
            if (_currentRole != null) {
              try {
                final roleId = _currentRole!.toLowerCase().replaceAll(' ', '-');
                await FirebaseFirestore.instance
                    .collection('roadmaps')
                    .doc(roleId)
                    .update(_roadmap!.toJson());
              } catch (e) {
                print('Error updating Firestore: $e');
                // Continue with local update
              }
            }
            
            break;
          }
        }
        if (taskFound) break;
      }
      
      if (taskFound) {
        notifyListeners();
      } else {
        print('Task $taskId not found');
      }
    } catch (e) {
      print('Error completing task: $e');
      rethrow;
    }
  }

  // Get tasks for a specific week
  List<RoadmapTask> getTasksForWeek(int weekNumber) {
    if (_roadmap == null) return [];
    
    final week = _roadmap!.weeks.firstWhere(
      (w) => w.weekNumber == weekNumber,
      orElse: () => RoadmapWeek(weekNumber: weekNumber, tasks: []),
    );
    
    return week.tasks;
  }

  // Get all tasks
  List<RoadmapTask> getAllTasks() {
    if (_roadmap == null) return [];
    
    final List<RoadmapTask> allTasks = [];
    for (var week in _roadmap!.weeks) {
      allTasks.addAll(week.tasks);
    }
    return allTasks;
  }

  // Get task by ID
  RoadmapTask? getTaskById(String taskId) {
    if (_roadmap == null) return null;
    
    for (var week in _roadmap!.weeks) {
      for (var task in week.tasks) {
        if (task.id == taskId) {
          return task;
        }
      }
    }
    return null;
  }

  // Get week by number
  RoadmapWeek? getWeekByNumber(int weekNumber) {
    if (_roadmap == null) return null;
    
    return _roadmap!.weeks.firstWhere(
      (week) => week.weekNumber == weekNumber,
      orElse: () => RoadmapWeek(weekNumber: weekNumber, tasks: []),
    );
  }

  // Calculate completion percentage
  double getCompletionPercentage() {
    if (_roadmap == null || _roadmap!.totalTasks == 0) return 0.0;
    
    int completedTasks = 0;
    for (var week in _roadmap!.weeks) {
      completedTasks += week.tasks.where((t) => t.completed).length;
    }
    
    return completedTasks / _roadmap!.totalTasks;
  }

  // Get total points earned
  int getTotalPointsEarned() {
    if (_roadmap == null) return 0;
    
    int totalPoints = 0;
    for (var week in _roadmap!.weeks) {
      for (var task in week.tasks) {
        if (task.completed) {
          totalPoints += task.points;
        }
      }
    }
    
    return totalPoints;
  }

  // Get tasks for today (based on day number)
  List<RoadmapTask> getTodayTasks() {
    if (_roadmap == null) return [];
    
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays + 1;
    final currentDay = (dayOfYear % 84) + 1; // Assuming 84 total tasks
    
    return getAllTasks().where((task) => task.day == currentDay).toList();
  }

  // Get next incomplete task
  RoadmapTask? getNextTask() {
    if (_roadmap == null) return null;
    
    for (var week in _roadmap!.weeks) {
      for (var task in week.tasks) {
        if (!task.completed) {
          return task;
        }
      }
    }
    return null;
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}