import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:techmafias/providers/auth.dart';
import 'package:techmafias/providers/roadmap.dart';
import 'package:techmafias/providers/daily_log.dart';
import 'package:techmafias/screens/tab/leaderboard_tab.dart';
import 'package:techmafias/screens/tab/project_tab.dart';
import 'package:techmafias/screens/tab/profile_tab.dart';
import 'package:techmafias/screens/tab/home_tab.dart';
import 'package:techmafias/providers/leaderboard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  bool _isLoading = true;
  bool _hasError = false;
  bool _dataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Fetch data only once after the first frame
    if (!_dataLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAuthAndLoadData();
      });
    }
  }

 Future<void> _checkAuthAndLoadData() async {
  if (_dataLoaded) return;

  try {
    // Get all providers
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dailyLogProvider = Provider.of<DailyLogProvider>(context, listen: false);
    final roadmapProvider = Provider.of<RoadmapProvider>(context, listen: false);
    
    // Get leaderboard provider if it exists
    LeaderboardProvider? leaderboardProvider;
    try {
      leaderboardProvider = Provider.of<LeaderboardProvider>(context, listen: false);
    } catch (e) {
      print('LeaderboardProvider not available: $e');
    }

    // Check authentication
    if (!authProvider.isAuthenticated || authProvider.user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    // Create list of futures to load
    List<Future> futures = [
      dailyLogProvider.fetchDailyLogs(),
      roadmapProvider.loadRoadmap(authProvider.user!.role),
    ];

    // Add leaderboard loading if provider exists
    if (leaderboardProvider != null) {
      futures.add(leaderboardProvider.fetchLeaderboard());
    }

    // Fetch all data in parallel
    await Future.wait(futures);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _dataLoaded = true;
      });
    }
  } catch (e) {
    print('Error loading dashboard data: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }
}

  void _retryLoading() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _dataLoaded = false;
      });
    }
    _checkAuthAndLoadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_hasError || !authProvider.isAuthenticated || authProvider.user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Unable to load dashboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              const Text('Please check your authentication', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _retryLoading, child: const Text('Retry')),
              const SizedBox(height: 10),
              TextButton(onPressed: () => authProvider.logout(), child: const Text('Logout')),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // REMOVED AppBar from here
      body: WillPopScope(
        onWillPop: () async {
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
              _pageController.jumpToPage(0);
            });
            return false;
          }
          return true;
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            HomeTab(), // Updated to use the new HomeTab
            LeaderboardTab(),
            ProjectsTab(),
            ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _pageController.jumpToPage(index);
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Roadmap'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}