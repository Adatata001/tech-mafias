import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/leaderboard.dart';
import '/providers/auth.dart';

class LeaderboardTab extends StatelessWidget {
  const LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LeaderboardProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildFilters(context),
          const SizedBox(height: 16),
          _buildStatsHeader(context),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: provider.getCombinedLeaderboard(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.fetchLeaderboard(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.leaderboard, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No leaderboard data yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Be the first to submit daily logs!',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.fetchLeaderboard(),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                final leaderboard = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: leaderboard.length,
                  itemBuilder: (context, index) {
                    final user = leaderboard[index];
                    final rank = index + 1;

                    return _buildLeaderboardCard(
                      context,
                      rank: rank,
                      username: user['username'] ?? 'Unknown',
                      points: user['points'] ?? 0,
                      streak: user['streak'] ?? 0,
                      email: user['email'] ?? '',
                      role: user['role'] ?? 'Member',
                      isCurrentUser: _isCurrentUser(context, user['userId']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentUser(BuildContext context, String userId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return userId == authProvider.user?.id;
  }

  Widget _buildFilters(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFilterButton(context, 'All Time', LeaderboardFilter.all),
        _buildFilterButton(context, 'Today', LeaderboardFilter.day),
        _buildFilterButton(context, 'This Week', LeaderboardFilter.week),
        _buildFilterButton(context, 'This Month', LeaderboardFilter.month),
      ],
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    String label,
    LeaderboardFilter value,
  ) {
    final provider = Provider.of<LeaderboardProvider>(context);

    return ElevatedButton(
      onPressed: () => provider.setFilter(value),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            provider.filter == value ? Colors.deepPurple : Colors.grey[300],
        foregroundColor:
            provider.filter == value ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Leaderboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          Consumer<LeaderboardProvider>(
            builder: (context, provider, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getFilterLabel(provider.filter),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getFilterLabel(LeaderboardFilter filter) {
    switch (filter) {
      case LeaderboardFilter.day:
        return 'Today';
      case LeaderboardFilter.week:
        return 'This Week';
      case LeaderboardFilter.month:
        return 'This Month';
      case LeaderboardFilter.all:
        return 'All Time';
    }
  }

  Widget _buildLeaderboardCard(
    BuildContext context, {
    required int rank,
    required String username,
    required int points,
    required int streak,
    required String email,
    required String role,
    required bool isCurrentUser,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.deepPurple[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? Colors.deepPurple : Colors.grey[200]!,
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRankColor(rank),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCurrentUser ? Colors.deepPurple : Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (rank <= 3)
                      Icon(
                        _getRankIcon(rank),
                        color: _getRankColor(rank),
                        size: 20,
                      ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(role),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Points
                    Row(
                      children: [
                        Icon(Icons.score, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '$points',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Streak
                        Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '$streak',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber[700]!;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown[400]!;
      default:
        return Colors.deepPurple;
    }
  }

  IconData _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.workspace_premium;
      case 3:
        return Icons.military_tech;
      default:
        return Icons.star;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'moderator':
        return Colors.orange;
      case 'premium':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }
}