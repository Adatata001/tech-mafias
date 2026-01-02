import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:techmafias/providers/auth.dart';
import 'package:techmafias/providers/roadmap.dart';
import 'package:techmafias/providers/daily_log.dart';
import 'package:techmafias/screens/tab/leaderboard_tab.dart';
import 'package:techmafias/screens/tab/project_tab.dart';
import 'package:techmafias/screens/tab/chat_tab.dart';
import 'package:techmafias/screens/tab/home_tab.dart';
import 'package:techmafias/providers/leaderboard.dart';
import 'package:techmafias/providers/chat.dart';

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
            HomeTab(),
            LeaderboardTab(),
            ProjectsTab(),
            ChatTab(conversationId: 'global_chat'),
          ],
        ),
      ),
      bottomNavigationBar: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: chatProvider.userConversations(),
            builder: (context, snapshot) {
              int unreadCount = 0;

              if (snapshot.hasData) {
                final conversations = snapshot.data!;
                final globalChat = conversations.firstWhere(
                  (c) => c['id'] == 'global_chat',
                  orElse: () => {},
                );

                unreadCount = globalChat['unreadCount'] ?? 0;
              }

              return BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) async {
                  if (index == 3) {
                    await chatProvider.markConversationAsRead('global_chat');
                  }

                  setState(() {
                    _selectedIndex = index;
                    _pageController.jumpToPage(index);
                  });
                },
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Colors.deepPurple,
                unselectedItemColor: Colors.grey,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.leaderboard),
                    label: 'Leaderboard',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.work),
                    label: 'Roadmap',
                  ),
                  BottomNavigationBarItem(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.chat),
                        if (unreadCount > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    label: 'Chat',
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  

  }
  
}
