class WeekendProject {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String role;
  final List<String> mediaUrls;
  final int week;
  final int year;
  final DateTime createdAt;

  const WeekendProject({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.role,
    required this.mediaUrls,
    required this.week,
    required this.year,
    required this.createdAt,
  });

  factory WeekendProject.fromJson(Map<String, dynamic> json, String id) {
    return WeekendProject(
      id: id,
      userId: json['userId'],
      title: json['title'],
      description: json['description'],
      role: json['role'],
      mediaUrls: List<String>.from(json['mediaUrls']),
      week: json['week'],
      year: json['year'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'role': role,
      'mediaUrls': mediaUrls,
      'week': week,
      'year': year,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
