import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/firebase.dart';

class ProjectProvider with ChangeNotifier {
  final List<WeekendProject> _projects = [];
  bool _isLoading = false;

  List<WeekendProject> get projects => _projects;
  bool get isLoading => _isLoading;

  Future<void> fetchProjects() async {
    _isLoading = true;
    notifyListeners();

    final snapshot = await FirebaseService.firestore
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .get();

    _projects.clear();

    for (var doc in snapshot.docs) {
      _projects.add(WeekendProject.fromJson(doc.data(), doc.id));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> submitProject(WeekendProject project) async {
    await FirebaseService.firestore
        .collection('projects')
        .add(project.toJson());

    await fetchProjects();
  }
}
