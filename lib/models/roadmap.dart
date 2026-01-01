class Roadmap {
  final String id;
  final String role;
  final int week;
  final int day;
  final String title;
  final String description;

  const Roadmap({
    required this.id,
    required this.role,
    required this.week,
    required this.day,
    required this.title,
    required this.description,
  });

  factory Roadmap.fromJson(Map<String, dynamic> json, String id) {
    return Roadmap(
      id: id,
      role: json['role'],
      week: json['week'],
      day: json['day'],
      title: json['title'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'week': week,
      'day': day,
      'title': title,
      'description': description,
    };
  }
}
