import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:techmafias/providers/auth.dart';
import 'package:techmafias/providers/chat.dart';
import 'package:techmafias/providers/roadmap.dart';
import 'package:techmafias/providers/daily_log.dart';
import 'package:techmafias/screens/auth.dart';
import 'package:techmafias/screens/dashboard.dart';
import 'package:techmafias/providers/project.dart';
import 'package:techmafias/providers/streak.dart';
import 'package:techmafias/providers/leaderboard.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AuthProvider()),
        ChangeNotifierProvider(create: (ctx) => DailyLogProvider()),
        ChangeNotifierProvider(create: (ctx) => RoadmapProvider()),
        ChangeNotifierProvider(create: (ctx) => ChatProvider()),
        ChangeNotifierProvider(create: (ctx) => ProjectProvider()),
        ChangeNotifierProvider(create: (ctx) => StreakProvider()),
        ChangeNotifierProvider(create: (ctx) => LeaderboardProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait a short moment to let AuthProvider load current user
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error during app initialization: $e');
    } finally {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Tech Mafia',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Show Auth screen if not authenticated
          if (!authProvider.isAuthenticated) {
            return const AuthScreen();
          }

          // Authenticated users go to Dashboard
          return const DashboardScreen();
        },
      ),
    );
  }
}
