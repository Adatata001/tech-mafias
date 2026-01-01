import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:techmafias/providers/auth.dart';
import 'package:techmafias/providers/roadmap.dart';

class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  bool _isLoading = false;
  int _selectedWeek = 1;

  @override
  void initState() {
    super.initState();
    _loadRoadmap();
  }

  Future<void> _loadRoadmap() async {
    setState(() => _isLoading = true);
    try {
      final roadmapProvider = Provider.of<RoadmapProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await roadmapProvider.loadRoadmap(authProvider.user!.role);
    } catch (e) {
      print("Error loading roadmap: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTaskCard(RoadmapTask task) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'D${task.day}',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              task.description,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            
            if (task.resources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resources:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: task.resources.map((resource) {
                      return Chip(
                        label: Text(
                          resource,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.deepPurple[50],
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSelector() {
    final roadmapProvider = Provider.of<RoadmapProvider>(context);
    
    if (roadmapProvider.weeks.isEmpty) {
      return const SizedBox();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Week',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: roadmapProvider.weeks.length,
              itemBuilder: (context, index) {
                final weekNumber = roadmapProvider.weeks[index].weekNumber;
                final isSelected = _selectedWeek == weekNumber;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Week $weekNumber'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedWeek = weekNumber;
                        });
                      }
                    },
                    selectedColor: Colors.deepPurple,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsGrid() {
    final roadmapProvider = Provider.of<RoadmapProvider>(context);
    final allTasks = roadmapProvider.getAllTasks();
    final projectTasks = allTasks.where((task) {
      final week = roadmapProvider.getWeekByNumber(task.week);
      if (week != null && week.tasks.isNotEmpty) {
        return task.id == week.tasks.last.id;
      }
      return false;
    }).toList();

    if (projectTasks.isEmpty) {
      return const Center(
        child: Text(
          'No projects available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projectTasks.length,
      itemBuilder: (context, index) {
        final task = projectTasks[index];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.assignment,
                          size: 30,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Week ${task.week} Project',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  task.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                
                if (task.resources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Resources:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: task.resources.map((resource) {
                          return Chip(
                            label: Text(
                              resource,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.deepPurple[50],
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roadmapProvider = Provider.of<RoadmapProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (_isLoading || roadmapProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (roadmapProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              roadmapProvider.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRoadmap,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (roadmapProvider.weeks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "No roadmap available for ${user?.role ?? ''}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRoadmap,
              child: const Text('Load Roadmap'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // REMOVED the custom header with SafeArea
            const TabBar(
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.deepPurple,
              tabs: [
                Tab(icon: Icon(Icons.timeline), text: 'Roadmap'),
                Tab(icon: Icon(Icons.assignment), text: 'Projects'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      _buildWeekSelector(),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: roadmapProvider.getTasksForWeek(_selectedWeek).length,
                          itemBuilder: (context, index) {
                            final tasks = roadmapProvider.getTasksForWeek(_selectedWeek);
                            final task = tasks[index];
                            return _buildTaskCard(task);
                          },
                        ),
                      ),
                    ],
                  ),
                  _buildProjectsGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}