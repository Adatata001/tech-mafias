class User {
  final String id;
  final String username;
  final String email;
  final String role;
  final int points;
  final int streak;
  final int techMafiaWins;
  final bool isMafiaOfTheWeek;
  final String? profilePhoto;
  final DateTime createdAt;
  final int? rank; // Leaderboard only

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.points,
    required this.streak,
    required this.techMafiaWins,
    required this.isMafiaOfTheWeek,
    required this.createdAt,
    this.profilePhoto,
    this.rank,
  });

  factory User.fromJson(Map<String, dynamic> json, String id) {
    return User(
      id: id,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      points: json['points'] ?? 0,
      streak: json['streak'] ?? 0,
      techMafiaWins: json['techMafiaWins'] ?? 0,
      isMafiaOfTheWeek: json['isMafiaOfTheWeek'] ?? false,
      profilePhoto: json['profilePhoto'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'role': role,
      'points': points,
      'streak': streak,
      'techMafiaWins': techMafiaWins,
      'isMafiaOfTheWeek': isMafiaOfTheWeek,
      'profilePhoto': profilePhoto,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? role,
    int? points,
    int? streak,
    int? techMafiaWins,
    bool? isMafiaOfTheWeek,
    String? profilePhoto,
    DateTime? createdAt,
    int? rank,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      points: points ?? this.points,
      streak: streak ?? this.streak,
      techMafiaWins: techMafiaWins ?? this.techMafiaWins,
      isMafiaOfTheWeek: isMafiaOfTheWeek ?? this.isMafiaOfTheWeek,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      createdAt: createdAt ?? this.createdAt,
      rank: rank ?? this.rank,
    );
  }
}
